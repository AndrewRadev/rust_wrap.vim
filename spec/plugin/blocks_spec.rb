require 'spec_helper'

describe "Basic" do
  let(:filename) { 'test.rs' }

  specify "goes inside nested blocks to find the last expression" do
    set_file_contents <<~EOF
      fn example() -> u32 {
          let one = 1;
          {
              println!("outer!");
              let two = 2;
              {
                  println!("inner!");
                  one + two
              }
          }
      }
    EOF

    vim.command('Wrap Result')
    vim.write

    assert_file_contents <<~EOF
      fn example() -> Result<u32, TODOError> {
          let one = 1;
          {
              println!("outer!");
              let two = 2;
              {
                  println!("inner!");
                  Ok(one + two)
              }
          }
      }
    EOF
  end
end
