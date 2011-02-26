-record(worker_state, {redis_connection, rabbit_connection, rabbit_channel, 
                       bridge_module, bridge_state, config}).
