# encoding: utf-8

Feature: Kungfuig is a pleasure to use

  @include @class
  Scenario: Configure with block should change options
   Given I include a Kungfuig module into class
    When I pass new option "option_1" with value "value_1" via block
    Then I get new option "option_1" with value "value_1"

  Scenario: Configure with hash should change options
   Given I include a Kungfuig module into class
    When I pass new option "option_1" with value "value_1" via hash
    Then I get new option "option_1" with value "value_1"

  Scenario: Configure with yaml file should change options
   Given I include a Kungfuig module into class
    When I pass new file "features/support/test.yml" to config
    Then I get new option "option_1" with value "value_1"

  Scenario: Configure with json file should change options
   Given I include a Kungfuig module into class
    When I pass new file "features/support/test.json" to config
    Then I get new option "option_1" with value "value_1"

  Scenario: Configure with json string should change options
   Given I include a Kungfuig module into class
    When I pass new file "{ "option_1": "value_1" }" to config
    Then I get new option "option_1" with value "value_1"

  Scenario: Configure with block via DSL should change options
   Given I include a Kungfuig module into class
    When I pass new option "option_1" with value "value_1" via block’s DSL
    Then I get new option "option_1" with value "value_1"

################################################################################

@include @instance
Scenario: Configure with block should change options
 Given I include a Kungfuig module into instance
  When I pass new option "option_1" with value "value_1" via block
  Then I get new option "option_1" with value "value_1"

Scenario: Configure with hash should change options
 Given I include a Kungfuig module into instance
  When I pass new option "option_1" with value "value_1" via hash
  Then I get new option "option_1" with value "value_1"

Scenario: Configure with yaml file should change options
 Given I include a Kungfuig module into instance
  When I pass new file "features/support/test.yml" to config
  Then I get new option "option_1" with value "value_1"

Scenario: Configure with json file should change options
 Given I include a Kungfuig module into instance
  When I pass new file "features/support/test.json" to config
  Then I get new option "option_1" with value "value_1"

Scenario: Configure with json string should change options
 Given I include a Kungfuig module into instance
  When I pass new file "{ "option_1": "value_1" }" to config
  Then I get new option "option_1" with value "value_1"

Scenario: Configure with block via DSL should change options
 Given I include a Kungfuig module into instance
  When I try to configure with DSL I yield an exception raised

################################################################################
