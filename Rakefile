# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/test_*.rb"]
  t.warning = false
  t.verbose = true
end

task default: :test

desc "Run cryptographic benchmarks"
task :bench do
  ruby "bin/vellum", "bench"
end

desc "Verify full proof systems"
task :verify_all do
  ruby "bin/vellum", "verify-all"
end

desc "Run comprehensive empirical benchmark suite"
task :benchmark_suite do
  ruby "benchmarks/benchmark_suite.rb"
end

desc "Execute and verify all end-to-end runnable examples"
task :examples do
  ruby "bin/verify-all-examples"
end
