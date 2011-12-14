Feature: Adhearsion Ahn CLI
  As a Adhearsion user
  I want a cli command (ahn)
  So that I can create and interact with adhearsion apps

  Scenario: No arguments given
    When I run `ahn`
    Then I should see the usage message
    And the exit status should be 0

  Scenario: Unrecoginized commands
    When I run `ahn alpha beta`
    Then the output should contain:
    """
    Unknown command: alpha beta
    """
    And the exit status should be 1

  Scenario: Command create with correct arguments
    When I run `ahn create path/somewhere`
    And I cd to "path/somewhere"
    Then the following files should exist:
      | dialplan.rb |
      | Gemfile |
      | README |
      | Rakefile |
      | config/adhearsion.rb |
      | config/environment.rb |
    And the file "dialplan.rb" should contain "adhearsion {"
    Then the exit status should be 0

  Scenario: Running create with no arguments
    When I run `ahn create`
    Then the output should contain:
    """
    Must specify something to create!
    """
    And the exit status should be 1

  Scenario: Command start with no path
    When I run `ahn start`
    Then the output should contain:
    """
    Invalid format for the start CLI command!
    """
    And the exit status should be 1
    
  @announce
  Scenario: Command start with only path works properly
    Given PENDING: Need to stop the ahn process
    Given I run `ahn create path/somewhere`
    When I run `ahn start path/somewhere` interactively
    Then the output should not contain "FATAL"
    And the output should contain:
    """
    Transitioning from booting to running
    """
    And the output should contain:
    """
    Transitioning from running to stopping
    """
    And the exit status should be 0
    
  @daemon
  Scenario: Command start with daemon option
    Given PENDING: Error -- undefined method `setsid'
    Given PENDING: Kill daemon using pid
    Given I run `ahn create path/somewhere`
    When I run `ahn start daemon path/somewhere`
    Then a file named "adhearsion.pid" should exist

  Scenario: Command start with console option
    Given PENDING: Need to stop the console and ahn process completly
    Given I run `ahn create path/somewhere`
    When I run `ahn start console path/somewhere` interactively
    And I type "quit"
    Then the output should contain "Starting console"
    And the output should contain "AHN>"

  Scenario: Command start with both console and daemon options
    Given I run `ahn create path/somewhere`
    When I run `ahn start console daemon path/somewhere`
    Then the output should contain:
    """
    Unrecognized final argument
    """
    Then the exit status should be 1

  @daemon
  Scenario: Command start with daemon and pid option
    Given PENDING: This gives an error "Unrecognized final argument"
    Given PENDING: Kill daemon using pid
    Given I run `ahn create path/somewhere`
    When I run `ahn start daemon path/somewhere --pid-file=ahn.pid`
    Then the output should contain:
    """
    Transitioning from booting to running
    """

  Scenario: Command start with valid path and pid option
    Given PENDING: This gives an error "Unrecognized final argument"
    Given I run `ahn create path/somewhere`
    When I run `ahn start path/somewhere --pid-file=ahn.pid`
    Then the output should contain:
    """
    Transitioning from booting to running
    """

  Scenario: Command version should print the version
    When I run `ahn version`
    Then the output should contain:
    """
    Adhearsion v
    """
    And the exit status should be 0

  Scenario: Command help
    When I run `ahn help`
    Then I should see the usage message
    And the exit status should be 0
