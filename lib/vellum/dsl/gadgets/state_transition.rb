# frozen_string_literal: true

require_relative "poseidon"
require_relative "range"

module Vellum
  module DSL
    module Gadgets
      # Confidential state transition gadget for private balance transfers
      # (e.g. Zcash / Tornado-style balance conservation without revealing balances or amounts).
      class StateTransitionGadget
        def self.verify_transfer(context, sender_old_bal, receiver_old_bal, transfer_amount, bits = 64)
          # 1. Non-negative transfer amount
          context.assert_range(transfer_amount, bits, "transfer_amt_positive")

          # 2. Sender updated balance
          sender_new_bal = sender_old_bal - transfer_amount
          # Assert sender has sufficient funds: sender_new_bal >= 0
          context.assert_range(sender_new_bal, bits, "sender_solvency")

          # 3. Receiver updated balance
          receiver_new_bal = receiver_old_bal + transfer_amount
          context.assert_range(receiver_new_bal, bits, "receiver_range")

          # 4. Generate state commitment hashes
          sender_old_comm = PoseidonGadget.hash_2(context, sender_old_bal, Signal.new(context, 0x1111))
          sender_new_comm = PoseidonGadget.hash_2(context, sender_new_bal, Signal.new(context, 0x1111))

          receiver_old_comm = PoseidonGadget.hash_2(context, receiver_old_bal, Signal.new(context, 0x2222))
          receiver_new_comm = PoseidonGadget.hash_2(context, receiver_new_bal, Signal.new(context, 0x2222))

          {
            sender_new_bal: sender_new_bal,
            receiver_new_bal: receiver_new_bal,
            sender_old_comm: sender_old_comm,
            sender_new_comm: sender_new_comm,
            receiver_old_comm: receiver_old_comm,
            receiver_new_comm: receiver_new_comm
          }
        end
      end
    end
  end
end
