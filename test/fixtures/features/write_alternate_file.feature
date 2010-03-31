Feature: Write a file

  Scenario: Write to hydra_test.txt
    Given an alternate target file
    When I write "HYDRA" to the file
    Then "HYDRA" should be written in the file

