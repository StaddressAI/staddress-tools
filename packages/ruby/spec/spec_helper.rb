# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "webmock/rspec"
require "staddress"

WebMock.disable_net_connect!

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed

  # 各テストが環境変数に依存しないようにする。
  config.around do |example|
    saved = ENV.to_hash.slice("STADDRESS_API_KEY", "STADDRESS_BASE_URL")
    ENV.delete("STADDRESS_API_KEY")
    ENV.delete("STADDRESS_BASE_URL")
    example.run
    ENV["STADDRESS_API_KEY"] = saved["STADDRESS_API_KEY"] if saved.key?("STADDRESS_API_KEY")
    ENV["STADDRESS_BASE_URL"] = saved["STADDRESS_BASE_URL"] if saved.key?("STADDRESS_BASE_URL")
  end
end
