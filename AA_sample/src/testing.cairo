use serde::Serde;
use starknet::ContractAddress;
use starknet::contract_address_to_felt252;
use array::ArrayTrait;
use debug::PrintTrait;


#[cfg(test)]
mod tests {
    use core::traits::Into;
    use core::array::ArrayTrait;
    use core::option::OptionTrait;
    use core::traits::TryInto;
    use core::result::ResultTrait;
    use snforge_std::declare;
    use starknet::ContractAddress;
    use snforge_std::ContractClassTrait;
    use starknet::info::get_block_number;
    use debug::PrintTrait;
    use starknet::get_caller_address;
    use snforge_std::start_prank;
    use snforge_std::start_warp;
    use snforge_std::stop_warp;
    use snforge_std::stop_prank;
    use core::dict::{Felt252Dict, Felt252DictTrait, SquashedFelt252Dict};
    use aa_auto_transactions::SubscriptionModel::Subscription;
    use aa_auto_transactions::SubscriptionModel::IServiceSubscriptionDispatcher;
    use aa_auto_transactions::SubscriptionModel::IServiceSubscriptionDispatcherTrait;
    use aa_auto_transactions::utils::erc20::IERC20Dispatcher;
    use aa_auto_transactions::utils::erc20::IERC20DispatcherTrait;
    use aa_auto_transactions::utils::account::AccountABIDispatcher;
    use aa_auto_transactions::utils::account::AccountABIDispatcherTrait;

    fn print_u(res: u256) {
        let a: felt252 = res.try_into().unwrap();
        let mut output: Array<felt252> = ArrayTrait::new();
        output.append(a);
        debug::print(output);
    }

    fn get_funds(reciever: ContractAddress, amount: u256) {
        let caller_who_have_funds: ContractAddress =
            0x00121108c052bbd5b273223043ad58a7e51c55ef454f3e02b0a0b4c559a925d4
            .try_into()
            .unwrap();
        let ETH_address: ContractAddress =
            0x049D36570D4e46f48e99674bd3fcc84644DdD6b96F7C741B1562B82f9e004dC7
            .try_into()
            .unwrap();
        let ETH = IERC20Dispatcher { contract_address: ETH_address };
        start_prank(ETH.contract_address, caller_who_have_funds);
        ETH.transfer(reciever, amount);
        stop_prank(ETH.contract_address);
    }

    fn get_balance(address: ContractAddress) -> u256 {
        let ETH_address: ContractAddress =
            0x049D36570D4e46f48e99674bd3fcc84644DdD6b96F7C741B1562B82f9e004dC7
            .try_into()
            .unwrap();
        let ETH = IERC20Dispatcher { contract_address: ETH_address };
        ETH.balanceOf(address)
    }

    fn get_acc(pub_key: felt252) -> ContractAddress {
        let cls = declare('Account');
        let mut constructor: Array::<felt252> = ArrayTrait::new();
        constructor.append(pub_key);
        let deployed = cls.deploy(@constructor).unwrap();
        return deployed;
    }

    fn get_sub_s(acc: ContractAddress) -> ContractAddress {
        let cls = declare('SimpleSubsribeServiceContract');
        let mut constructor: Array::<felt252> = ArrayTrait::new();
        constructor.append(acc.into());
        let deployed = cls.deploy(@constructor).unwrap();
        return deployed;
    }

    fn get_sub_s_02() -> ContractAddress {
        let cls = declare('SimpleSubsribeServiceContract02');
        let mut constructor: Array::<felt252> = ArrayTrait::new();
        let deployed = cls.deploy(@constructor).unwrap();
        return deployed;
    }

    #[test]
    #[ignore]
    //#[available_gas(10000000000)]
    #[fork("latest")]
    fn test_01() {
        let amount = 1000000000000000000;
        assert(1 == 1, 'LOL');

        let ETH_address: ContractAddress =
            0x049D36570D4e46f48e99674bd3fcc84644DdD6b96F7C741B1562B82f9e004dC7
            .try_into()
            .unwrap();
        let ETH = IERC20Dispatcher { contract_address: ETH_address };
        let pub_key = 0x30e73be48fdd88083aa49beae396784073adab7d7c76a9fe566c7355c5b0572;
        let acc_address: ContractAddress = get_acc(pub_key);
        let sub_s_address = get_sub_s(acc_address);

        get_funds(acc_address, amount);

        let aa = AccountABIDispatcher { contract_address: acc_address };
        let sub_s = IServiceSubscriptionDispatcher { contract_address: sub_s_address };

        let subscription_info = Subscription {
            payment_amount: 1,
            payment_token: ETH_address,
            sub_period_in_seconds: 1000,
            sub_id: 0,
            max_periods_allowed: 5,
        };

        start_warp(acc_address, 1000);
        start_prank(aa.contract_address, acc_address);
        aa.add_subscription(sub_s_address, subscription_info, 5);
        stop_prank(acc_address);
        stop_warp(acc_address);
        let (is_sub_s, lst_t, sub_info) = aa.subscription_status(sub_s_address, 0);
        print_u(get_balance(acc_address));

        let prev_b = get_balance(acc_address);

        start_warp(sub_s.contract_address, 2000);
        start_prank(aa.contract_address, sub_s.contract_address);
        aa.pay(sub_s.contract_address, 0);
        stop_prank(aa.contract_address);
        stop_warp(sub_s.contract_address);
        let (is_sub_s, lst_t, sub_info) = aa.subscription_status(sub_s_address, 0);
        print_u(get_balance(acc_address));

        assert(prev_b - get_balance(acc_address) == 1, 'failed_test_01');
    }

    #[test]
    #[ignore]
    //#[available_gas(10000000000)]
    #[should_panic(expected: ('Fail validate pay',))]
    #[fork("latest")]
    fn test_02() {
        let amount = 1000000000000000000;
        assert(1 == 1, 'LOL');

        let ETH_address: ContractAddress =
            0x049D36570D4e46f48e99674bd3fcc84644DdD6b96F7C741B1562B82f9e004dC7
            .try_into()
            .unwrap();
        let ETH = IERC20Dispatcher { contract_address: ETH_address };
        let pub_key = 0x30e73be48fdd88083aa49beae396784073adab7d7c76a9fe566c7355c5b0572;
        let acc_address: ContractAddress = get_acc(pub_key);
        let sub_s_address = get_sub_s(acc_address);

        get_funds(acc_address, amount);

        let aa = AccountABIDispatcher { contract_address: acc_address };
        let sub_s = IServiceSubscriptionDispatcher { contract_address: sub_s_address };

        let subscription_info = Subscription {
            payment_amount: 1,
            payment_token: ETH_address,
            sub_period_in_seconds: 1000,
            sub_id: 0,
            max_periods_allowed: 5,
        };

        start_warp(aa.contract_address, 1000);
        start_prank(aa.contract_address, acc_address);
        aa.add_subscription(sub_s_address, subscription_info, 5);
        stop_prank(acc_address);
        stop_warp(aa.contract_address);
        let (is_sub_s, lst_t, sub_info) = aa.subscription_status(sub_s_address, 0);
        print_u(get_balance(acc_address));

        let prev_b = get_balance(acc_address);

        start_warp(aa.contract_address, 1001);
        start_prank(aa.contract_address, sub_s.contract_address);
        aa.pay(sub_s.contract_address, 0);
        stop_prank(aa.contract_address);
        stop_warp(aa.contract_address);
        let (is_sub_s, lst_t, sub_info) = aa.subscription_status(sub_s_address, 0);
        print_u(get_balance(acc_address));

        assert(prev_b - get_balance(acc_address) == 0, 'failed_test_02');
    }

    #[test]
    //#[available_gas(10000000000)]
    #[fork("latest")]
    #[ignore]
    fn test_03() {
        let amount = 1000000000000000000;
        assert(1 == 1, 'LOL');

        let ETH_address: ContractAddress =
            0x049D36570D4e46f48e99674bd3fcc84644DdD6b96F7C741B1562B82f9e004dC7
            .try_into()
            .unwrap();
        let ETH = IERC20Dispatcher { contract_address: ETH_address };
        let pub_key = 0x30e73be48fdd88083aa49beae396784073adab7d7c76a9fe566c7355c5b0572;
        let acc_address: ContractAddress = get_acc(pub_key);
        let sub_s_address = get_sub_s_02();

        get_funds(acc_address, amount);

        let aa = AccountABIDispatcher { contract_address: acc_address };
        let sub_s = IServiceSubscriptionDispatcher { contract_address: sub_s_address };

        let subscription_info = Subscription {
            payment_amount: 1,
            payment_token: ETH_address,
            sub_period_in_seconds: 1000,
            sub_id: 0,
            max_periods_allowed: 5,
        };

        start_warp(aa.contract_address, 1000);
        start_prank(aa.contract_address, acc_address);
        aa.add_subscription(sub_s_address, subscription_info, 5);
        stop_prank(acc_address);
        stop_warp(aa.contract_address);
        let (is_sub_s, lst_t, sub_info) = aa.subscription_status(sub_s_address, 0);
        print_u(get_balance(acc_address));

        let prev_b = get_balance(acc_address);

        start_warp(aa.contract_address, 2000);
        start_prank(aa.contract_address, sub_s.contract_address);
        aa.pay(sub_s.contract_address, 0);
        stop_prank(aa.contract_address);
        stop_warp(aa.contract_address);
        let (is_sub_s, lst_t, sub_info) = aa.subscription_status(sub_s_address, 0);
        print_u(get_balance(acc_address));

        assert(prev_b - get_balance(acc_address) == 1, 'failed_test_03');
    }

    #[test]
    //#[available_gas(10000000000)]
    #[fork("latest")]
    #[ignore]
    fn test_04() {
        let amount = 1000000000000000000;
        assert(1 == 1, 'LOL');

        let ETH_address: ContractAddress =
            0x049D36570D4e46f48e99674bd3fcc84644DdD6b96F7C741B1562B82f9e004dC7
            .try_into()
            .unwrap();
        let ETH = IERC20Dispatcher { contract_address: ETH_address };
        let pub_key = 0x30e73be48fdd88083aa49beae396784073adab7d7c76a9fe566c7355c5b0572;
        let acc_address: ContractAddress = get_acc(pub_key);
        let sub_s_address = get_sub_s_02();

        get_funds(acc_address, amount);

        let aa = AccountABIDispatcher { contract_address: acc_address };
        let sub_s = IServiceSubscriptionDispatcher { contract_address: sub_s_address };

        let subscription_info = Subscription {
            payment_amount: 1,
            payment_token: ETH_address,
            sub_period_in_seconds: 1000,
            sub_id: 0,
            max_periods_allowed: 5,
        };

        start_warp(aa.contract_address, 1000);
        start_prank(aa.contract_address, acc_address);
        aa.add_subscription(sub_s_address, subscription_info, 5);
        stop_prank(acc_address);
        stop_warp(aa.contract_address);
        let (is_sub_s, lst_t, sub_info) = aa.subscription_status(sub_s_address, 0);
        print_u(get_balance(acc_address));

        let prev_b = get_balance(acc_address);

        start_warp(sub_s.contract_address, 2000);
        sub_s.collect_sub(aa.contract_address, 0);
        stop_warp(sub_s.contract_address);
        let (is_sub_s, lst_t, sub_info) = aa.subscription_status(sub_s_address, 0);
        print_u(get_balance(acc_address));

        assert(prev_b - get_balance(acc_address) == 1, 'failed_test_04');
    }

        #[test]
    //#[available_gas(10000000000)]
    #[should_panic(expected: ('max_calls fail',))]
    #[fork("latest")]
    fn test_05() {
        let amount = 1000000000000000000;
        assert(1 == 1, 'LOL');

        let ETH_address: ContractAddress =
            0x049D36570D4e46f48e99674bd3fcc84644DdD6b96F7C741B1562B82f9e004dC7
            .try_into()
            .unwrap();
        let ETH = IERC20Dispatcher { contract_address: ETH_address };
        let pub_key = 0x30e73be48fdd88083aa49beae396784073adab7d7c76a9fe566c7355c5b0572;
        let acc_address: ContractAddress = get_acc(pub_key);
        let sub_s_address = get_sub_s_02();

        get_funds(acc_address, amount);

        let aa = AccountABIDispatcher { contract_address: acc_address };
        let sub_s = IServiceSubscriptionDispatcher { contract_address: sub_s_address };

        let subscription_info = Subscription {
            payment_amount: 1,
            payment_token: ETH_address,
            sub_period_in_seconds: 1000,
            sub_id: 0,
            max_periods_allowed: 5,
        };

        start_warp(aa.contract_address, 1000);
        start_prank(aa.contract_address, acc_address);
        aa.add_subscription(sub_s_address, subscription_info, 5);
        stop_prank(acc_address);
        stop_warp(aa.contract_address);
        let (is_sub_s, lst_t, sub_info) = aa.subscription_status(sub_s_address, 0);
        print_u(get_balance(acc_address));

        let prev_b = get_balance(acc_address);

        start_warp(sub_s.contract_address, 2000);
        start_warp(aa.contract_address, 2000);
        sub_s.collect_sub(aa.contract_address, 0);
        stop_warp(aa.contract_address);
        stop_warp(sub_s.contract_address);
        let (is_sub_s, lst_t, sub_info) = aa.subscription_status(sub_s_address, 0);
        print_u(get_balance(acc_address));

        start_warp(sub_s.contract_address, 4000);
        start_warp(aa.contract_address, 4000);
        sub_s.collect_sub(aa.contract_address, 0);
        stop_warp(aa.contract_address);
        stop_warp(sub_s.contract_address);
        let (is_sub_s, lst_t, sub_info) = aa.subscription_status(sub_s_address, 0);
        print_u(get_balance(acc_address));

        start_warp(sub_s.contract_address, 6000);
        start_warp(aa.contract_address, 6000);
        sub_s.collect_sub(aa.contract_address, 0);
        stop_warp(aa.contract_address);
        stop_warp(sub_s.contract_address);
        let (is_sub_s, lst_t, sub_info) = aa.subscription_status(sub_s_address, 0);
        print_u(get_balance(acc_address));

        start_warp(sub_s.contract_address, 8000);
        start_warp(aa.contract_address, 8000);
        sub_s.collect_sub(aa.contract_address, 0);
        stop_warp(aa.contract_address);
        stop_warp(sub_s.contract_address);
        let (is_sub_s, lst_t, sub_info) = aa.subscription_status(sub_s_address, 0);
        print_u(get_balance(acc_address));

        start_warp(sub_s.contract_address, 10000);
        start_warp(aa.contract_address, 10000);
        sub_s.collect_sub(aa.contract_address, 0);
        stop_warp(aa.contract_address);
        stop_warp(sub_s.contract_address);
        let (is_sub_s, lst_t, sub_info) = aa.subscription_status(sub_s_address, 0);
        print_u(get_balance(acc_address));



        assert(prev_b - get_balance(acc_address) == 5, 'failed_test_05');
    }
}
