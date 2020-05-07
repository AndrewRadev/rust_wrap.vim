require 'spec_helper'

describe "Basic" do
  let(:filename) { 'test.rs' }

  specify "wraps match branches individually" do
    set_file_contents <<~EOF
      fn example() -> u32 { // comment
          match true { // comment
              true         => 0, // comment
              false        => 1, // comment
              true | false => 2, // comment
              _            => 3, // comment
          } // comment
      } // comment
    EOF

    vim.command('Wrap Result')
    vim.write

    assert_file_contents <<~EOF
      fn example() -> Result<u32, TODOError> { // comment
          match true { // comment
              true         => Ok(0), // comment
              false        => Ok(1), // comment
              true | false => Ok(2), // comment
              _            => Ok(3), // comment
          } // comment
      } // comment
    EOF
  end
end
