

#[starknet::component]
mod service_subscribe_component {
    
    use starknet::{ContractAddress,get_block_info, get_contract_address,get_caller_address};
    use aa_auto_transactions::interfaces::{Subscription,IUserSubscription,IServiceSubscriptionDispatcher,IServiceSubscriptionDispatcherTrait,
    IUserSubscriptionDispatcher, IUserSubscriptionDispatcherTrait,IServiceSubscription};
    use aa_auto_transactions::utils::erc20::{IERC20Dispatcher,IERC20DispatcherTrait};

    #[storage]
    struct Storage {
        name: felt252,
        sub_id_to_sub_info: LegacyMap::<u256, Subscription>,
        user_sub_to_last_payment_time: LegacyMap::<(ContractAddress, u256), u256>,
        fee_recipient: ContractAddress,
        bips_reward: u256,
        collected_fee: (ContractAddress, u256),
        pay_for_subscription_lock: bool,
        collect_lock: bool
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ServiceSubscription: ServiceSubscription,
        InvokerReward: InvokerReward
    }

    #[derive(Drop, starknet::Event)]
    struct ServiceSubscription {
        #[key]
        sub_user: ContractAddress,
        #[key]
        sub_id: u256,
        actual_amount: u256
    }

    #[derive(Drop, starknet::Event)]
    struct InvokerReward {
        #[key]
        sub_user: ContractAddress,
        #[key]
        sub_id: u256,
        amount: u256,
        recipient: ContractAddress
    }


    #[embeddable_as(ServiceSubscriptble)]
    impl ServiceSubscriptbleImpl<
        TContractState, +HasComponent<TContractState>
    > of IServiceSubscription<ComponentState<TContractState>> {
        fn name(self: @ComponentState<TContractState>) -> felt252 {
            return self.name.read();
        }
        fn get_subscription_info(
            self: @ComponentState<TContractState>, sub_id: u256
        ) -> Subscription {
            return self.sub_id_to_sub_info.read(sub_id);
        }

        fn pay_for_subscription(ref self: ComponentState<TContractState>, sub_id: u256) -> bool {
            assert(!self.pay_for_subscription_lock.read(), 'pay_for_subscription lock');
            self.pay_for_subscription_lock.write(true);
            let caller = get_caller_address();

            let (token, collected_fee): (ContractAddress, u256) = self.collected_fee.read();
            //  if somebody try to do scam stuff we just tfer reward fee to our fee recipient
            if collected_fee > 0 {
                //IERC20Dispatcher { contract_address: token }
                //    .transfer(self.fee_recipient.read(), collected_fee);
                self
                    .emit(
                        InvokerReward {
                            sub_user: caller,
                            sub_id: sub_id,
                            amount: collected_fee,
                            recipient: self.fee_recipient.read()
                        }
                    );
            }
            let sub_info = self.get_subscription_info(sub_id);
            let erc20 = IERC20Dispatcher { contract_address: sub_info.payment_token };

            let bips_reward: u256 = sub_info.payment_amount * self.bips_reward.read() / 10000;
            if bips_reward == 0 {
                erc20.transferFrom(caller, self.fee_recipient.read(), sub_info.payment_amount);
                self.collected_fee.write((token, 0));
            } else {
                erc20
                    .transferFrom(
                        caller, self.fee_recipient.read(), sub_info.payment_amount - bips_reward
                    );
                self.collected_fee.write((sub_info.payment_token, bips_reward));
            }

            self
                .user_sub_to_last_payment_time
                .write((caller, sub_id), get_block_info().unbox().block_timestamp.into());
            self
                .emit(
                    ServiceSubscription {
                        sub_user: caller,
                        sub_id: sub_info.sub_id,
                        actual_amount: sub_info.payment_amount
                    }
                );

            self.pay_for_subscription_lock.write(false);
            return true;
        }
        fn terminate_subscription(
            ref self: ComponentState<TContractState>, sub_id: u256
        ) { // no refund logic  sorry
        // self.user_sub_to_last_payment.write(0);
        }

        fn is_subscribed(
            self: @ComponentState<TContractState>, user: ContractAddress, sub_id: u256
        ) -> bool {
            let sub_info = self.get_subscription_info(sub_id);
            let elapsed = get_block_info().unbox().block_timestamp.into()
                - self.user_sub_to_last_payment_time.read((user, sub_id));
            if elapsed == 0 || elapsed > sub_info.sub_period_in_seconds {
                return false;
            }
            return true;
        }

        fn collect_sub(
            ref self: ComponentState<TContractState>, user: ContractAddress, sub_id: u256
        ) -> bool {
            assert(!self.collect_lock.read(), 'collect_lock');
            let user_acc = IUserSubscriptionDispatcher { contract_address: user };
            let caller = get_caller_address();
            user_acc.pay(get_contract_address(), sub_id);

            let (token, collected_fee): (ContractAddress, u256) = self.collected_fee.read();
            if collected_fee > 0 {
                IERC20Dispatcher { contract_address: token }.transfer(caller, collected_fee);
                self.collected_fee.write((token, 0));
                self
                    .emit(
                        InvokerReward {
                            sub_user: user, sub_id: sub_id, amount: collected_fee, recipient: caller
                        }
                    );
            }

            self.collect_lock.write(false);
            return true;
        }
    }
}