# frozen_string_literal: true

# Same as pure DLQ version until rebalance

setup_karafka(allow_errors: %w[consumer.consume.error])

create_topic(name: DT.topics[0], partitions: 100)
create_topic(name: DT.topics[1], partitions: 100)

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:partitions] << message.partition
    end

    raise StandardError
  end
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:broken] << message.partition
    end
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer
    dead_letter_queue(topic: DT.topics[1], max_retries: 0)
    manual_offset_management true
  end

  topic DT.topics[1] do
    consumer DlqConsumer
    manual_offset_management true
  end
end

100.times do |i|
  elements = DT.uuids(100)
  produce_many(DT.topic, elements, partition: i)
end

start_karafka_and_wait_until do
  DT[:partitions].uniq.count >= 2 &&
    DT[:broken].uniq.count >= 5
end

# No need for any assertions as if it would pipe only to one, it would hang and crash via timeout
