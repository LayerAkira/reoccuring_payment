mod SubscriptionModel {
    use starknet::ContractAddress;

    #[derive(Copy, Drop, Serde, starknet::Store, PartialEq)]
    struct Subscription {
        payment_amount: u256, // amount paid for Subscription
        payment_token: ContractAddress, // in what token paid for Subscription
        duration_sec: u256, // duration of subscription in sec
        sub_id: u256, // identifier of subscription, user can have several diff subscription for specific service
    }

    #[starknet::interface]
    trait IServiceSubscription<TContractState> {
        fn name(self: @TContractState, subscription: ContractAddress, sub_id: u256) -> felt252;
        fn get_subscription_info(self: @TContractState, sub_id: u256) -> Subscription;
        fn pay_subscription(
            ref self: TContractState, sub_id: u256
        ) -> bool; // can only be paid by those who implement view 
    }

    #[starknet::interface]
    trait IUserSubscription<TContractState> {
        fn add_subscription(
            ref self: TContractState,
            subscription_service: ContractAddress,
            sub: Subscription,
            max_settlments: u256
        );
        fn remove_subscription(
            ref self: TContractState, sub_service: ContractAddress, sub_id: u256
        );
        fn pay(ref self: TContractState, sub_service: ContractAddress, sub_id: u256);

        fn subscription_status(
            self: @TContractState, subscription: ContractAddress, sub_id: u256
        ) -> (bool, u256, Subscription);
    }
}

#[starknet::component]
mod user_subscrible_component {
    use core::traits::TryInto;
    use core::traits::Into;
    use core::box::BoxTrait;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use super::SubscriptionModel::Subscription;
    use super::SubscriptionModel::IUserSubscription;
    use super::SubscriptionModel::IServiceSubscriptionDispatcher;
    use super::SubscriptionModel::IServiceSubscriptionDispatcherTrait;
    use starknet::get_block_info;
    use starknet::get_contract_address;
    use openzeppelin::token::erc20::interface::ERC20ABIDispatcher;
    use openzeppelin::token::erc20::interface::ERC20ABIDispatcherTrait;


    // useIServiceSubscription

    #[storage]
    struct Storage {
        sub_to_sub_info: LegacyMap::<(ContractAddress, u256), Subscription>,
        sub_to_last_called: LegacyMap::<(ContractAddress, u256), u256>,
        sub_to_max_calls: LegacyMap::<(ContractAddress, u256), u256>
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        SubscriptionPayment: SubscriptonPayment,
        SubscriptionCancelled: SubscriptonCancelled
    }

    #[derive(Drop, starknet::Event)]
    struct SubscriptonPayment {
        #[key]
        sub_service: ContractAddress,
        #[key]
        sub_id: u256,
        actual_amount: u256,
        registered: bool
    }


    #[derive(Drop, starknet::Event)]
    struct SubscriptonCancelled {
        #[key]
        sub_service: ContractAddress,
        #[key]
        sub_id: u256,
    }

    #[embeddable_as(UserSubscriptble)]
    impl UserSubscriptbleImpl<
        TContractState, +HasComponent<TContractState>
    > of IUserSubscription<ComponentState<TContractState>> {
        fn subscription_status(
            self: @ComponentState<TContractState>, subscription: ContractAddress, sub_id: u256
        ) -> (bool, u256, Subscription) {
            let last_called = self.sub_to_last_called.read((subscription, sub_id));
            let sub = self.sub_to_sub_info.read((subscription, sub_id));
            if last_called == 0 {
                return (false, 0, sub);
            }
            return (true, last_called, sub);
        }
        fn remove_subscription(
            ref self: ComponentState<TContractState>, sub_service: ContractAddress, sub_id: u256
        ) {
            assert(self._contains(sub_service, sub_id), 'No subscription found');
            let key = (sub_service, sub_id);
            self.sub_to_last_called.write(key, 0);
            self.sub_to_max_calls.write(key, 0);
            self.emit(SubscriptonCancelled { sub_service, sub_id })
        }

        fn add_subscription(
            ref self: ComponentState<TContractState>,
            subscription_service: ContractAddress,
            sub: Subscription,
            max_settlments: u256
        ) {
            assert(max_settlments > 0, 'Wrong max_settlements');

            assert(self._contains(subscription_service, sub.sub_id) == false, 'subscription found');

            let key = (subscription_service, sub.sub_id);

            self.sub_to_max_calls.write(key, max_settlments);

            let sub_contract = IServiceSubscriptionDispatcher {
                contract_address: subscription_service
            };
            let real_sub_info = sub_contract.get_subscription_info(sub.sub_id);
            assert(sub == real_sub_info, 'Wrong sub info');
            self.sub_to_sub_info.write(key, real_sub_info);
            let real_paid = self._pay_for_sub(subscription_service, sub);

            self
                .emit(
                    SubscriptonPayment {
                        sub_service: subscription_service,
                        sub_id: sub.sub_id,
                        actual_amount: real_paid,
                        registered: true
                    }
                )
        }

        fn pay(
            ref self: ComponentState<TContractState>, sub_service: ContractAddress, sub_id: u256
        ) {
            assert(self._contains(sub_service, sub_id), 'No sub');
            assert(self._validate_pay(sub_service, sub_id), 'Fail validate pay');
            let sub = self.sub_to_sub_info.read((sub_service, sub_id));
            let real_paid = self._pay_for_sub(sub_service, sub);

            self
                .emit(
                    SubscriptonPayment {
                        sub_service: sub_service,
                        sub_id: sub_id,
                        actual_amount: real_paid,
                        registered: false
                    }
                )
        }
    }
    #[generate_trait]
    impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn _contains(
            self: @ComponentState<TContractState>, subscription: ContractAddress, sub_id: u256
        ) -> bool {
            let last_called = self.sub_to_last_called.read((subscription, sub_id));
            if last_called == 0 {
                return false;
            }
            return true;
        }
        fn _validate_pay(
            self: @ComponentState<TContractState>, subscription: ContractAddress, sub_id: u256
        ) -> bool {
            let key = (subscription, sub_id);
            if self._contains(subscription, sub_id) == false {
                return false;
            }
            if self.sub_to_max_calls.read(key) == 0 {
                return false;
            }
            let sub = self.sub_to_sub_info.read(key);
            if get_block_info().unbox().block_timestamp.into()
                - self.sub_to_last_called.read(key) < sub.duration_sec {
                return false;
            }
            return true;
        }
        fn _pay_for_sub(
            ref self: ComponentState<TContractState>,
            service_sub: ContractAddress,
            sub: Subscription
        ) -> u256 {
            let key = (service_sub, sub.sub_id);
            let erc20 = ERC20ABIDispatcher { contract_address: sub.payment_token };
            let sub_contract = IServiceSubscriptionDispatcher { contract_address: service_sub };

            let user = get_contract_address();
            let cur_allowance = erc20.allowance(user, service_sub);
            if cur_allowance != 0 {
                assert(erc20.approve(service_sub, 0), 'Failed to reset allowance');
            }
            assert(
                erc20.approve(service_sub, sub.payment_amount), 'Failed to set allowance for sub'
            );
            let cur_balance = erc20.balance_of(user);

            assert(sub_contract.pay_subscription(sub.sub_id), 'Failed to pay');
            self.sub_to_last_called.write(key, get_block_info().unbox().block_timestamp.into());
            self.sub_to_max_calls.write(key, self.sub_to_max_calls.read(key) - 1);

            assert(erc20.approve(service_sub, cur_allowance), 'Failed to set orig allowance');
            return erc20.balance_of(user) - cur_balance;
        }
    }
}
