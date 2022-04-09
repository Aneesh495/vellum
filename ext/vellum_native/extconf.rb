# frozen_string_literal: true

require "mkmf"

abort "Missing stdint.h" unless have_header("stdint.h")
abort "Missing stdbool.h" unless have_header("stdbool.h")
abort "Missing string.h" unless have_header("string.h")

$CFLAGS << " -O3 -Wall -Wextra -std=c99"

create_makefile("vellum/vellum_native")
