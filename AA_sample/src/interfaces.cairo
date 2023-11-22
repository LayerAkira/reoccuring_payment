use starknet::ContractAddress;

#[derive(Copy, Drop, Serde, starknet::Store, PartialEq)]
struct Subscription {
    payment_amount: u256, // amount paid for Subscription
    payment_token: ContractAddress, // in what token paid for Subscription
    sub_period_in_seconds: u256, // duration of subscription in sec
    sub_id: u256, // identifier of subscription, user can have several diff subscription for specific service
    max_periods_allowed: u256 // service specify how much periods one can use
}



#[starknet::interface]
trait IServiceSubscription<TContractState> {
    fn name(self: @TContractState) -> felt252;
    fn get_subscription_info(self: @TContractState, sub_id: u256) -> Subscription;
    fn pay_for_subscription(ref self: TContractState, sub_id: u256) -> bool; // invoked to process subs payment        
    fn terminate_subscription(
        ref self: TContractState, sub_id: u256
    ); // handles processing of cancellation of subscription, eg refund
    fn is_subscribed(self: @TContractState, user: ContractAddress, sub_id: u256) -> bool;

    fn collect_sub(ref self: TContractState, user: ContractAddress, sub_id: u256) -> bool;
}

#[starknet::interface]
trait IUserSubscription<TContractState> {
    fn add_subscription( // only user can invoke, starts subscription and pays for period
        ref self: TContractState,
        sub_service: ContractAddress,
        sub_info: Subscription,
        max_settlments: u256
    );
    fn remove_subscription(
        ref self: TContractState, sub_service: ContractAddress, sub_id: u256
    ); // only user can invoke, terminates subscription

    // initiate payment for subscription, only can be initiated by user or subscription service
    fn pay(ref self: TContractState, sub_service: ContractAddress, sub_id: u256);

    fn subscription_status(
        self: @TContractState, sub_service: ContractAddress, sub_id: u256
    ) -> (bool, u256, Subscription); // (is_sub presented, last time it was executed ,sub info)

    fn validate_pay(
        self: @TContractState, sub_service: ContractAddress, sub_id: u256
    ) -> bool; // validates if one can proceed with payment
}

