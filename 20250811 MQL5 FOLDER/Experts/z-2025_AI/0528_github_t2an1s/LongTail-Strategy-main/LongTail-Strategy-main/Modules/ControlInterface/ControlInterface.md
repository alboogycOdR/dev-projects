
This Master module holds all the core logic that defines the LongTailStrategy(LTS)...

START
    Init sequence

    call daily sessions ☑️
    track_daily_session(is_end_session);
    if (use_daily_session && is_end_session && is_empty_chart())
        return;
    // manage mismanagement ☑️
    check_strategy_rules();

    // call new position ☑️
    check_new_position(last_saved_ticket, last_saved_type);

    // manage delay ☑️
    check_zero_position();

    Log session
    Log off
END