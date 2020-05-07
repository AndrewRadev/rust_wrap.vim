require 'spec_helper'

describe "Basic" do
  let(:filename) { 'test.rs' }

  specify "wraps code in Result" do
    set_file_contents <<~EOF
      fn example() -> u32 {
          return 0;
          42
      }
    EOF

    vim.command('Wrap Result')
    vim.write

    assert_file_contents <<~EOF
      fn example() -> Result<u32, TODOError> {
          return Ok(0);
          Ok(42)
      }
    EOF
  end

  specify "wraps code in Option" do
    set_file_contents <<~EOF
      fn example() -> u32 {
          return 0;
          42
      }
    EOF

    vim.command('Wrap Option')
    vim.write

    assert_file_contents <<~EOF
      fn example() -> Option<u32> {
          return Some(0);
          Some(42)
      }
    EOF
  end

  specify "wraps code in Rc" do
    set_file_contents <<~EOF
      fn example() -> u32 {
          return 0;
          42
      }
    EOF

    vim.command('Wrap Rc')
    vim.write

    assert_file_contents <<~EOF
      fn example() -> Rc<u32> {
          return Rc::new(0);
          Rc::new(42)
      }
    EOF
  end

  specify "preserves comments" do
    set_file_contents <<~EOF
      fn example() -> u32 {
          return 0; // comment
          42 // comment
      }
    EOF

    vim.command('Wrap Rc')
    vim.write

    assert_file_contents <<~EOF
      fn example() -> Rc<u32> {
          return Rc::new(0); // comment
          Rc::new(42) // comment
      }
    EOF
  end
end
