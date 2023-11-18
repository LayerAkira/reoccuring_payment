#[starknet::contract]
mod SimpleSubsribeServiceContract {
    use aa_auto_transactions::SubscriptionModel::Subscription;
    use core::traits::Into;
    use core::array::ArrayTrait;
    use core::option::OptionTrait;
    use core::traits::TryInto;
    use core::result::ResultTrait;
    use snforge_std::declare;
    use starknet::ContractAddress;
    use snforge_std::ContractClassTrait;
    use starknet::info::get_block_number;
    use starknet::info::get_contract_address;
    use debug::PrintTrait;
    use starknet::get_caller_address;
    use snforge_std::start_prank;
    use snforge_std::stop_prank;
    use core::dict::{Felt252Dict, Felt252DictTrait, SquashedFelt252Dict};
    use aa_auto_transactions::utils::erc20::IERC20Dispatcher;
    use aa_auto_transactions::utils::erc20::IERC20DispatcherTrait;

    #[storage]
    struct Storage {
        sub: Subscription,
        acc_address: ContractAddress,
    }

    #[constructor]
    fn constructor(ref self: ContractState, acc_address: ContractAddress) {
        let ETH_address: ContractAddress =
            0x049D36570D4e46f48e99674bd3fcc84644DdD6b96F7C741B1562B82f9e004dC7
            .try_into()
            .unwrap();
        self
            .sub
            .write(
                Subscription {
                    payment_amount: 1,
                    payment_token: ETH_address,
                    sub_period_in_seconds: 1000,
                    sub_id: 0,
                    max_periods_allowed: 5,
                }
            );

        self.acc_address.write(acc_address);
    }

    #[external(v0)]
    fn name(self: @ContractState) -> felt252 {
        'lol'
    }
    #[external(v0)]
    fn get_subscription_info(self: @ContractState, sub_id: u256) -> Subscription {
        let sub = Subscription {
            payment_amount: 1,
            payment_token: get_contract_address(),
            sub_period_in_seconds: 1000,
            sub_id: 0,
            max_periods_allowed: 5,
        };
        self.sub.read()
    }
    #[external(v0)]
    fn pay_for_subscription(ref self: ContractState, sub_id: u256) -> bool {
        let ETH_address: ContractAddress =
            0x049D36570D4e46f48e99674bd3fcc84644DdD6b96F7C741B1562B82f9e004dC7
            .try_into()
            .unwrap();
        let ETH = IERC20Dispatcher { contract_address: ETH_address };
        assert(
            ETH
                .allowance(self.acc_address.read(), get_contract_address()) >= self
                .sub
                .read()
                .payment_amount,
            'wrong allowance'
        );
        ETH
            .transferFrom(
                self.acc_address.read(), get_contract_address(), self.sub.read().payment_amount
            );
        true
    }
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        a: a,
    }

    #[derive(Drop, starknet::Event)]
    struct a {}
}
