#[starknet::contract]
mod SimpleSubsribeServiceContract02 {
    use aa_auto_transactions::interfaces::Subscription;
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
    use aa_auto_transactions::service_subscribe_component::service_subscribe_component;

    component!(path: service_subscribe_component, storage: ssc_s, event: ssc_e);

    #[abi(embed_v0)]
    impl UserSubscriptbleImpl = service_subscribe_component::ServiceSubscriptble<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        ssc_s: service_subscribe_component::Storage,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        let ETH_address: ContractAddress =
            0x049D36570D4e46f48e99674bd3fcc84644DdD6b96F7C741B1562B82f9e004dC7
            .try_into()
            .unwrap();
        self.ssc_s.name.write('Spotify');
        self
            .ssc_s
            .sub_id_to_sub_info
            .write(
                0,
                Subscription {
                    payment_amount: 1,
                    payment_token: ETH_address,
                    sub_period_in_seconds: 1000,
                    sub_id: 0,
                    max_periods_allowed: 5,
                }
            );
        self.ssc_s.fee_recipient.write(get_contract_address());
        self.ssc_s.bips_reward.write(0);
    }
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        ab: ab,
        ssc_e: service_subscribe_component::Event,
    }

    #[derive(Drop, starknet::Event)]
    struct ab {}
}
