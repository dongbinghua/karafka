# frozen_string_literal: true

# Karafka should use more than one thread to consume independent topics partitions

setup_karafka do |config|
  config.concurrency = 10
  config.initial_offset = 'latest'
end

create_topic(partitions: 10)

class Consumer < Karafka::BaseConsumer
  def consume
    # This will simulate, that the thread is busy in a bit random way, so more worker threads can
    # be occupied
    sleep(1)

    messages.each do |message|
      DT[message.partition] << Thread.current.object_id
    end
  end

  def shutdown
    mark_as_consumed!(messages.last)
  end
end

draw_routes do
  consumer_group DT.consumer_group do
    # Special topic with 10 partitions available
    topic DT.topic do
      consumer Consumer
    end
  end
end

# Start Karafka
Thread.new { Karafka::Server.run }

# Give it some time to boot and connect before dispatching messages
sleep(5)

# We send only one message to each topic partition, so when messages are consumed, it forces them
# to be in separate worker threads
10.times { |i| produce(DT.topic, SecureRandom.hex(6), partition: i) }

wait_until do
  DT.data.values.flatten.size >= 10
end

# 10 partitions are expected
assert_equal 10, DT.data.size
# In 10 threads due to sleep
assert_equal 10, DT.data.values.flatten.uniq.count
