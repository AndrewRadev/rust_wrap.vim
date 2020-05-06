require 'spec_helper'

describe "Basic" do
  let(:filename) { 'test.rs' }

  specify "wraps match branches individually" do
    set_file_contents <<~EOF
      fn example() -> u32 {
          match true {
              true         => 0,
              false        => 1,
              true | false => 2,
              _            => 3,
          }
      }
    EOF

    vim.command('Wrap Result')
    vim.write

    assert_file_contents <<~EOF
      fn example() -> Result<u32, TODOError> {
          match true {
              true         => Ok(0),
              false        => Ok(1),
              true | false => Ok(2),
              _            => Ok(3),
          }
      }
    EOF
  end
end
