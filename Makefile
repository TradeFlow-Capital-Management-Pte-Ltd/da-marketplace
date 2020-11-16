BASENAME=$(shell yq -r '.catalog.name' < dabl-meta.yaml 2> /dev/null || yq r dabl-meta.yaml 'catalog.name')
VERSION=$(shell yq -r '.catalog.version' < dabl-meta.yaml 2> /dev/null || yq r dabl-meta.yaml 'catalog.version')
SUBDEPLOYMENTS=$(shell yq -r '.subdeployments' < dabl-meta.yaml 2> /dev/null | sed 's/\[//g' | sed 's/\]//g' | sed 's/,//g' \
	       || yq r dabl-meta.yaml 'subdeployments' | sed 's/\[//g' | sed 's/\]//g' | sed 's/,//g')

TAG_NAME=${BASENAME}-v${VERSION}
NAME=${BASENAME}-${VERSION}

dar_version := $(shell grep "^version" daml.yaml | sed 's/version: //g')
trigger_version := $(shell grep "^version" triggers/daml.yaml | sed 's/version: //g')
exberry_adapter_version := $(shell cd exberry_adapter && poetry version | cut -f 2 -d ' ')
matching_engine_version := $(shell cd matching_engine && poetry version | cut -f 2 -d ' ')
operator_bot_version := $(shell cd automation/operator && poetry version | cut -f 2 -d ' ')
issuer_bot_version := $(shell cd automation/issuer && poetry version | cut -f 2 -d ' ')
custodian_bot_version := $(shell cd automation/custodian && poetry version | cut -f 2 -d ' ')
broker_bot_version := $(shell cd automation/broker && poetry version | cut -f 2 -d ' ')
exchange_bot_version := $(shell cd automation/exchange && poetry version | cut -f 2 -d ' ')
ui_version := $(shell node -p "require(\"./ui/package.json\").version")


state_dir := .dev
daml_build_log = $(state_dir)/daml_build.log
sandbox_pid := $(state_dir)/sandbox.pid
sandbox_log := $(state_dir)/sandbox.log

trigger_build := triggers/.daml/dist/marketplace-triggers-$(trigger_version).dar

exberry_adapter_dir := exberry_adapter/bot.egg-info
adapter_pid := $(state_dir)/adapter.pid
adapter_log := $(state_dir)/adapter.log

matching_engine_dir := matching_engine/bot.egg-info
matching_engine_pid := $(state_dir)/matching_engine.pid
matching_engine_log := $(state_dir)/matching_engine.log

operator_bot_dir := automation/operator/bot.egg-info
operator_pid := $(state_dir)/operator.pid
operator_log := $(state_dir)/operator.log

issuer_bot_dir := automation/issuer/bot.egg-info
issuer_pid := $(state_dir)/issuer.pid
issuer_log := $(state_dir)/issuer.log

custodian_bot_dir := automation/custodian/bot.egg-info
custodian_pid := $(state_dir)/custodian.pid
custodian_log := $(state_dir)/custodian.log

broker_bot_dir := automation/broker/bot.egg-info
broker_pid := $(state_dir)/broker.pid
broker_log := $(state_dir)/broker.log

exchange_bot_dir := automation/exchange/bot.egg-info
exchange_pid := $(state_dir)/exchange.pid
exchange_log := $(state_dir)/exchange.log


### DAML server
.PHONY: clean stop_daml_server stop_operator stop_issuer stop_custodian stop_broker stop_exchange stop_adapter stop_matching_engine

$(state_dir):
	mkdir $(state_dir)

$(daml_build_log): |$(state_dir)
	daml build > $(daml_build_log)

$(sandbox_pid): |$(daml_build_log)
	daml start > $(sandbox_log) & echo "$$!" > $(sandbox_pid)

start_daml_server: $(sandbox_pid)

stop_daml_server:
	pkill -F $(sandbox_pid); rm -f $(sandbox_pid) $(sandbox_log)


### DA Marketplace Operator Bot
$(operator_bot_dir):
	cd automation/operator && poetry install && poetry build

$(trigger_build):
	cd triggers && daml build

.PHONY: clean_triggers
clean_triggers:
	rm $(trigger_build)

$(operator_pid): |$(state_dir) $(trigger_build)
	cd triggers && (daml trigger --dar .daml/dist/marketplace-triggers-0.0.1.dar \
	    --trigger-name OperatorTrigger:handleOperator \
	    --ledger-host localhost --ledger-port 6865 \
	    --ledger-party Operator > ../$(operator_log) & echo "$$!" > ../$(operator_pid))

start_operator: $(operator_pid)

stop_operator:
	pkill -F $(operator_pid); rm -f $(operator_pid) $(operator_log)

### DA Marketplace Issuer Bot
$(issuer_bot_dir):
	cd automation/issuer && poetry install && poetry build

$(issuer_pid): |$(state_dir) $(trigger_build) # $(issuer_bot_dir)
	cd triggers && (daml trigger --dar .daml/dist/marketplace-triggers-0.0.1.dar \
	    --trigger-name PublicTrigger:handlePublic \
	    --ledger-host localhost --ledger-port 6865 \
	    --ledger-party Operator > ../$(issuer_log) & echo "$$!" > ../$(issuer_pid))
	# cd automation/issuer && (DAML_LEDGER_URL=localhost:6865 poetry run python bot/issuer_bot.py > ../../$(issuer_log) & echo "$$!" > ../../$(issuer_pid))

start_issuer: $(issuer_pid)

stop_issuer:
	pkill -F $(issuer_pid); rm -f $(issuer_pid) $(issuer_log)


### DA Marketplace Custodian Bot
$(custodian_bot_dir):
	cd automation/custodian && poetry install && poetry build

$(custodian_pid): |$(state_dir) $(trigger_build) # $(custodian_bot_dir)
	cd triggers && (daml trigger --dar .daml/dist/marketplace-triggers-0.0.1.dar \
	    --trigger-name CustodianTrigger:handleCustodian \
	    --ledger-host localhost --ledger-port 6865 \
	    --ledger-party Custodian > ../$(custodian_log) & echo "$$!" > ../$(custodian_pid))

start_custodian: $(custodian_pid)

stop_custodian:
	pkill -F $(custodian_pid); rm -f $(custodian_pid) $(custodian_log)


### DA Marketplace Broker Bot
$(broker_bot_dir):
	cd automation/broker && poetry install && poetry build

$(broker_pid): |$(state_dir) $(trigger_build) # $(broker_bot_dir)
	cd triggers && (daml trigger --dar .daml/dist/marketplace-triggers-0.0.1.dar \
	    --trigger-name BrokerTrigger:handleBroker \
	    --ledger-host localhost --ledger-port 6865 \
	    --ledger-party Broker > ../$(broker_log) & echo "$$!" > ../$(broker_pid))

start_broker: $(broker_pid)

stop_broker:
	pkill -F $(broker_pid); rm -f $(broker_pid) $(broker_log)


### DA Marketplace Exchange Bot
$(exchange_bot_dir):
	cd automation/exchange && poetry install && poetry build

$(exchange_pid): |$(state_dir) $(trigger_build) # $(exchange_bot_dir)
	cd triggers && (daml trigger --dar .daml/dist/marketplace-triggers-0.0.1.dar \
	    --trigger-name ExchangeTrigger:handleExchange \
	    --ledger-host localhost --ledger-port 6865 \
	    --ledger-party Exchange > ../$(exchange_log) & echo "$$!" > ../$(exchange_pid))

start_exchange: $(exchange_pid)

stop_exchange:
	pkill -F $(exchange_pid); rm -f $(exchange_pid) $(exchange_log)


### DA Marketplace <> Exberry Adapter
$(exberry_adapter_dir):
	cd exberry_adapter && poetry install && poetry build

$(adapter_pid): |$(state_dir) $(exberry_adapter_dir)
	cd exberry_adapter && (DAML_LEDGER_URL=localhost:6865 poetry run python bot/exberry_adapter_bot.py > ../$(adapter_log) & echo "$$!" > ../$(adapter_pid))

start_adapter: $(adapter_pid)

stop_adapter:
	pkill -F $(adapter_pid); rm -f $(adapter_pid) $(adapter_log)


### DA Marketplace Matching Engine
$(matching_engine_dir):
	cd matching_engine && poetry install && poetry build

$(matching_engine_pid): |$(state_dir) $(trigger_build) # $(matching_engine_dir)
	cd triggers && (daml trigger --dar .daml/dist/marketplace-triggers-0.0.1.dar \
	    --trigger-name MatchingEngine:handleMatching \
	    --ledger-host localhost --ledger-port 6865 \
	    --ledger-party Exchange > ../$(matching_engine_log) & echo "$$!" > ../$(matching_engine_pid))
	# cd matching_engine && (DAML_LEDGER_URL=localhost:6865 poetry run python bot/matching_engine_bot.py > ../$(matching_engine_log) & echo "$$!" > ../$(matching_engine_pid))

start_matching_engine: $(matching_engine_pid)

stop_matching_engine:
	pkill -F $(matching_engine_pid); rm -f $(matching_engine_pid) $(matching_engine_log)

start_bots: $(operator_pid) $(broker_pid) $(custodian_pid) $(exchange_pid) $(issuer_pid)

stop_bots: stop_broker stop_custodian stop_exchange stop_issuer stop_operator

target_dir := target

dar := $(target_dir)/da-marketplace-model-$(dar_version).dar
exberry_adapter := $(target_dir)/da-marketplace-exberry-adapter-$(exberry_adapter_version).tar.gz
matching_engine := $(target_dir)/da-marketplace-matching-engine-$(matching_engine_version).tar.gz
operator_bot := $(target_dir)/da-marketplace-operator-bot-$(operator_bot_version).tar.gz
issuer_bot := $(target_dir)/da-marketplace-issuer-bot-$(issuer_bot_version).tar.gz
custodian_bot := $(target_dir)/da-marketplace-custodian-bot-$(custodian_bot_version).tar.gz
broker_bot := $(target_dir)/da-marketplace-broker-bot-$(broker_bot_version).tar.gz
exchange_bot := $(target_dir)/da-marketplace-exchange-bot-$(exchange_bot_version).tar.gz
ui := $(target_dir)/da-marketplace-ui-$(ui_version).zip
dabl_meta := $(target_dir)/dabl-meta.yaml

$(target_dir):
	mkdir $@

.PHONY: package publish

publish: package
	git tag -f "${TAG_NAME}"
	ghr -replace "${TAG_NAME}" "$(target_dir)/${NAME}.dit"

# some_files = $(shell cd $(target_dir) && echo da-marketplace-*)
# helloooo = $(filter-out da-marketplace-exberry%.gz, $(some_files))
package: $(operator_bot) $(issuer_bot) $(custodian_bot) $(broker_bot) $(exchange_bot) $(exberry_adapter) $(matching_engine) $(dar) $(ui) $(dabl_meta) verify-artifacts
	cd $(target_dir) && zip ${NAME}.dit $(filter-out da-marketplace-exberry%.tar.gz, $(shell cd $(target_dir) && echo da-marketplace-*)) dabl-meta.yaml

$(dabl_meta): $(target_dir) dabl-meta.yaml
	cp dabl-meta.yaml $@

$(dar): $(target_dir) $(daml_build_log)
	cp .daml/dist/da-marketplace-$(dar_version).dar $@

$(operator_bot): $(target_dir) $(operator_bot_dir)
	cp automation/operator/dist/bot-$(operator_bot_version).tar.gz $@

$(issuer_bot): $(target_dir) $(issuer_bot_dir)
	cp automation/issuer/dist/bot-$(issuer_bot_version).tar.gz $@

$(custodian_bot): $(target_dir) $(custodian_bot_dir)
	cp automation/custodian/dist/bot-$(custodian_bot_version).tar.gz $@

$(broker_bot): $(target_dir) $(broker_bot_dir)
	cp automation/broker/dist/bot-$(broker_bot_version).tar.gz $@

$(exchange_bot): $(target_dir) $(exchange_bot_dir)
	cp automation/exchange/dist/bot-$(exchange_bot_version).tar.gz $@

$(exberry_adapter): $(target_dir) $(exberry_adapter_dir)
	cp exberry_adapter/dist/bot-$(exberry_adapter_version).tar.gz $@

$(matching_engine): $(target_dir) $(matching_engine_dir)
	cp matching_engine/dist/bot-$(matching_engine_version).tar.gz $@

$(ui):
	daml codegen js .daml/dist/da-marketplace-$(dar_version).dar -o daml.js
	cd ui && yarn install
	cd ui && yarn build
	cd ui && zip -r da-marketplace-ui-$(ui_version).zip build
	mv ui/da-marketplace-ui-$(ui_version).zip $@
	rm -r ui/build

.PHONY: clean
clean: clean-ui
	rm -rf $(state_dir) $(exberry_adapter_dir) $(exberry_adapter) $(matching_engine_dir) $(matching_engine) $(operator_bot_dir) $(operator_bot) $(issuer_bot_dir) $(issuer_bot) $(custodian_bot_dir) $(custodian_bot) $(broker_bot_dir) $(broker_bot) $(exchange_bot) $(dar) $(ui) $(dabl_meta) $(target_dir)/${NAME}.dit

clean-ui:
	rm -rf $(ui) daml.js ui/node_modules ui/build ui/yarn.lock

verify-artifacts:
	for filename in $(SUBDEPLOYMENTS) ; do \
		test -f $(target_dir)/$$filename || (echo could not find $$filename; exit 1;) \
	done
	test -f $(dabl_meta) || (echo could not find $(dabl_meta); exit 1;) \
