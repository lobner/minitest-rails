require "rake/testtask"
require "minitest/rails/testing"
require "minitest/rails/tasks/sub_test_task"

namespace "test" do
  task :prepare do
    # Define here in case test_unit isn't loaded
  end
end

desc "Run default tests"
task :minitest do
  Rake::Task["minitest:default"].invoke
end

namespace "minitest" do

  # Main entry point for minitest
  task :default do
    if ENV["TEST"]
      Rake::Task["minitest:single"].invoke
    else
      Rake::Task["minitest:run"].invoke
    end
  end

  # Run a single test
  Minitest::Rails::Tasks::SubTestTask.new(single: "test:prepare") do |t|
    t.libs << "test"
  end

  # Run the default tests as definded in Minitest::Rails::Testing.default_tasks
  Minitest::Rails::Tasks::SubTestTask.new(run: "test:prepare") do |t|
    t.libs.push "test"
    t.pattern = "test/{#{Minitest::Rails::Testing.default_tasks.join(',')}}/**/*_test.rb"
  end

  # Run the default tests as definded in Minitest::Rails::Testing.default_tasks
  desc "Runs the default tests, without resetting the db"
  Minitest::Rails::Tasks::SubTestTask.new(:quick) do |t|
    t.libs.push "test"
    t.pattern = "test/{#{Minitest::Rails::Testing.default_tasks.join(',')}}/**/*_test.rb"
  end

  desc "Runs all tests"
  Minitest::Rails::Tasks::SubTestTask.new(all: "test:prepare") do |t|
    t.libs.push "test"
    t.pattern = "test/**/*_test.rb"
  end

  namespace "all" do
    desc "Runs all tests, without resetting the db"
    Minitest::Rails::Tasks::SubTestTask.new(:quick) do |t|
      t.libs.push "test"
      t.pattern = "test/**/*_test.rb"
    end
  end

  # Loop that will define a task for each directory that has tests
  Minitest::Rails::Testing.all_tasks.each do |task_dir|
    unless Rake::Task.task_defined? "minitest:#{task_dir}"
      desc "Runs tests under test/#{task_dir}"
      Minitest::Rails::Tasks::SubTestTask.new(task_dir => "test:prepare") do |t|
        t.libs.push "test"
        t.pattern = "test/#{task_dir}/**/*_test.rb"
      end
    end
  end

end

# Statistics

# set hook on stats task
task stats: "minitest:setup_stats"

namespace "minitest" do
  task :setup_stats do
    require "rails/code_statistics"

    # Clear existing test directories
    STATS_DIRECTORIES.reject! { |name, dir| dir.starts_with? Rails.root.join("test").to_s }
    CodeStatistics::TEST_TYPES.clear

    # Add test directories that minitest-rails knows about
    Minitest::Rails::Testing.all_tasks.each do |dir|
      name = "#{dir.capitalize} tests"
      STATS_DIRECTORIES << [ name, Rails.root.join("test").join(dir).to_s ]
      CodeStatistics::TEST_TYPES << name
    end
  end
end

# Define tasks under "test" if they don't already exist
if !Rake::Task.task_defined? :test
  desc "Runs default tests"
  task test: "minitest"

  namespace "test" do
    Minitest::Rails::Testing.all_tasks.each do |task_dir|
      desc "Runs tests under test/#{task_dir}"
      task task_dir => "minitest:#{task_dir}"
    end

    desc "Runs the default tests, without resetting the db"
    task quick: "minitest:quick"

    desc "Runs all tests"
    task all: "minitest:all"

    namespace "all" do
      desc "Runs all tests, without resetting the db"
      task quick: "minitest:all:quick"
    end
  end
end

# Override the default task
task default: [] # Just in case it hasn't already been set
Rake::Task[:default].clear
task default: "minitest"
