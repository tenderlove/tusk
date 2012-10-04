###
# Tusk contains observers with different message bus strategies.
#
# Tusk::Observers::Redis offers an Observer API with Redis as the
# message bus.  Tusk::Observers::PG offers and Observer API with
# PostgreSQL as the message bus.  Tusk::Observers::DRb offers an
# Observer API with DRb as the message bus.
module Tusk
  VERSION = '1.1.0'
end
