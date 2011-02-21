PACKAGE=rabbitmq-redis
DEPS=rabbitmq-erlang-client
#INTERNAL_DEPS=erldis
DEPS_FILE=deps.mk
TEST_APPS=amqp_client
START_RABBIT_IN_TESTS=true
TEST_COMMANDS=rabbit_redis_test:test()

include ../include.mk

$(DEPS_FILE): $(SOURCES) $(INCLUDES)
	escript generate_deps $(INCLUDE_DIR) $(SOURCE_DIR) \$$\(EBIN_DIR\) $@

clean::
	rm -f $(DEPS_FILE)

-include $(DEPS_FILE)
