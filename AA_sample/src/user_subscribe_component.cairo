
#[starknet::component]
mod user_subscrible_component {
    use core::{traits::Into,box::BoxTrait};
    use starknet::{ContractAddress,get_caller_address,get_block_info,get_contract_address};
    use aa_auto_transactions::interfaces::{Subscription,IUserSubscription,IServiceSubscriptionDispatcher,IServiceSubscriptionDispatcherTrait};
    use aa_auto_transactions::utils::erc20::{IERC20Dispatcher,IERC20DispatcherTrait};


    #[storage]
    struct Storage {
        sub_service_to_sub_info: LegacyMap::<(ContractAddress, u256), Subscription>,
        sub_service_to_last_called: LegacyMap::<(ContractAddress, u256), u256>,
        sub_service_to_max_calls: LegacyMap::<(ContractAddress, u256), u256>
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
            self: @ComponentState<TContractState>, sub_service: ContractAddress, sub_id: u256
        ) -> (bool, u256, Subscription) {
            let last_called = self.sub_service_to_last_called.read((sub_service, sub_id));
            let sub_info = self.sub_service_to_sub_info.read((sub_service, sub_id));
            if last_called == 0 {
                return (false, 0, sub_info);
            }
            return (true, last_called, sub_info);
        }
        fn remove_subscription(
            ref self: ComponentState<TContractState>, sub_service: ContractAddress, sub_id: u256
        ) {
            assert(get_caller_address() == get_contract_address(), 'Only self');
            assert(self._contains(sub_service, sub_id), 'No subscription found');
            let key = (sub_service, sub_id);
            self.sub_service_to_last_called.write(key, 0);
            self.sub_service_to_max_calls.write(key, 0);
            self.emit(SubscriptonCancelled { sub_service, sub_id });

            let sub_contract = IServiceSubscriptionDispatcher { contract_address: sub_service };
            sub_contract.terminate_subscription(sub_id);
        }

        fn add_subscription(
            ref self: ComponentState<TContractState>,
            sub_service: ContractAddress,
            sub_info: Subscription,
            max_settlments: u256
        ) {
            assert(get_caller_address() == get_contract_address(), 'Only self');
            assert(max_settlments > 0, 'Wrong max_settlements');
            assert(max_settlments <= sub_info.max_periods_allowed, 'Wrong max_settlments');

            assert(self._contains(sub_service, sub_info.sub_id) == false, 'subscription found');

            let key = (sub_service, sub_info.sub_id);

            self.sub_service_to_max_calls.write(key, max_settlments);

            let sub_contract = IServiceSubscriptionDispatcher { contract_address: sub_service };
            let real_sub_info = sub_contract.get_subscription_info(sub_info.sub_id);
            assert(sub_info.sub_period_in_seconds == real_sub_info.sub_period_in_seconds, 'Wrong sub info');
                        // assert(sub_info.sub_period_in_seconds == real_sub_info.sub_period_in_seconds, 'Wrong sub info');
                        //             assert(sub_info.sub_period_in_seconds == real_sub_info.sub_period_in_seconds, 'Wrong sub info');
                        //                         assert(sub_info.sub_period_in_seconds == real_sub_info.sub_period_in_seconds, 'Wrong sub info');

            self.sub_service_to_sub_info.write(key, real_sub_info);
            let real_paid = self._pay_for_sub(sub_service, sub_info);

            self
                .emit(
                    SubscriptonPayment {
                        sub_service: sub_service,
                        sub_id: sub_info.sub_id,
                        actual_amount: real_paid,
                        registered: true
                    }
                )
        }

        fn pay(
            ref self: ComponentState<TContractState>, sub_service: ContractAddress, sub_id: u256
        ) {
            let caller = get_caller_address();
            assert(sub_service == caller || get_contract_address() == caller, 'Wrong invoker');

            assert(self._contains(sub_service, sub_id), 'No sub');
            assert(self._validate_pay(sub_service, sub_id), 'Fail validate pay');
            let sub_info = self.sub_service_to_sub_info.read((sub_service, sub_id));
            let real_paid = self._pay_for_sub(sub_service, sub_info);

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

        fn validate_pay(
            self: @ComponentState<TContractState>, sub_service: ContractAddress, sub_id: u256
        ) -> bool {
            return self._validate_pay(sub_service, sub_id);
        }
    }
    #[generate_trait]
    impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn _contains(
            self: @ComponentState<TContractState>, sub_service: ContractAddress, sub_id: u256
        ) -> bool {
            let last_called = self.sub_service_to_last_called.read((sub_service, sub_id));
            if last_called == 0 {
                return false;
            }
            return true;
        }
        fn _validate_pay(
            self: @ComponentState<TContractState>, sub_service: ContractAddress, sub_id: u256
        ) -> bool {
            let key = (sub_service, sub_id);
            if self._contains(sub_service, sub_id) == false {
                return false;
            }
            if self.sub_service_to_max_calls.read(key) == 0 {
                return false;
            }
            let sub_info = self.sub_service_to_sub_info.read(key);
            if get_block_info().unbox().block_timestamp.into()
                - self.sub_service_to_last_called.read(key) < sub_info.sub_period_in_seconds {
                return false;
            }
            return true;
        }
        fn _pay_for_sub(
            ref self: ComponentState<TContractState>,
            service_sub: ContractAddress,
            sub_info: Subscription
        ) -> u256 {
            let key = (service_sub, sub_info.sub_id);
            let erc20 = IERC20Dispatcher { contract_address: sub_info.payment_token };
            let sub_contract = IServiceSubscriptionDispatcher { contract_address: service_sub };

            let user = get_contract_address();
            let cur_allowance = erc20.allowance(user, service_sub);
            if cur_allowance != 0 {
                assert(erc20.approve(service_sub, 0), 'Failed to reset allowance');
            }
            assert(
                erc20.approve(service_sub, sub_info.payment_amount),
                'Failed to set allowance for sub'
            );
            let cur_balance = erc20.balanceOf(user);

            assert(sub_contract.pay_for_subscription(sub_info.sub_id), 'Failed to pay');
            self
                .sub_service_to_last_called
                .write(key, get_block_info().unbox().block_timestamp.into());
            self.sub_service_to_max_calls.write(key, self.sub_service_to_max_calls.read(key) - 1);

            assert(erc20.approve(service_sub, cur_allowance), 'Failed to set orig allowance');
            return cur_balance - erc20.balanceOf(user);
        }
    }
}