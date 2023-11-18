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
    trait IViewUserSubscription<TContractState> {
        fn subscription_status(
            self: @TContractState, subscription: ContractAddress, sub_id: u256
        ) -> (bool, u256);
    }
    #[starknet::interface]
    trait IUserSubscription<TContractState> {
        fn name(self: @TContractState, subscription: ContractAddress, sub_id: u256) -> felt252;
        fn get_subscription_info(self: @TContractState, sub_id: u256) -> Subscription;
        fn pay_subscription(
            ref self: TContractState, sub_id: u256
        ) -> Subscription; // can only be paid by those who implement view 
    }

    #[starknet::interface]
    trait IUserPayments<TContractState> {
        fn add_subscription(
            ref self: TContractState,
            subscription_service: ContractAddress,
            sub: Subscription,
            max_settlments: u256
        );
        fn remove_subscription(
            ref self: TContractState, sub_service: ContractAddress, sub_id: u256
        );
        fn renounce_ownership(ref self: TContractState);
        fn pay(ref self: TContractState, sub_id: u256);
    }
}
