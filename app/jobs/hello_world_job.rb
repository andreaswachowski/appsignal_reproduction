class HelloWorldJob < ApplicationJob
  queue_as :default

  def perform(*args)
    nil
  end
end
