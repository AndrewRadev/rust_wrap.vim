require 'spec_helper'

describe "Basic" do
  let(:filename) { 'test.rs' }

  specify "wraps if-else branches individually" do
    set_file_contents <<~EOF
      fn example() -> u32 {
          if 1 > 0 {
              println!("OK");
              13
          } else if 13 + 14 == 27 {
              println!("Reasonable");
              27
          } else {
              println!("Shocking!");
              17
          }
      }
    EOF

    vim.command('Wrap Result')
    vim.write

    assert_file_contents <<~EOF
      fn example() -> Result<u32, TODOError> {
          if 1 > 0 {
              println!("OK");
              Ok(13)
          } else if 13 + 14 == 27 {
              println!("Reasonable");
              Ok(27)
          } else {
              println!("Shocking!");
              Ok(17)
          }
      }
    EOF
  end
end
