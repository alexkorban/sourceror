defmodule SourcerorTest do
  use ExUnit.Case, async: true
  doctest Sourceror

  describe "parse_string!/2" do
    test "raises on invalid string" do
      assert_raise SyntaxError, fn ->
        Sourceror.parse_string!(":ok end")
      end

      assert_raise TokenMissingError, fn ->
        Sourceror.parse_string!("do :ok")
      end
    end
  end

  describe "parse_expression/2" do
    test "parses only the first valid expression" do
      assert {:ok, {:foo, _, [[{{_, _, [:do]}, {_, _, [:ok]}}]]}, _} =
               Sourceror.parse_expression(~S"""
               foo do
                 :ok
               end

               42
               """)
    end

    test "does not success on empty strings" do
      assert {:error, _} = Sourceror.parse_expression("")

      assert {:ok, {:__block__, _, [:ok]}, ""} =
               Sourceror.parse_expression(~S"""

               :ok
               """)
    end

    test "parses starting from line" do
      source = ~S"""
      :a
      foo do
        :ok
      end
      :c
      """

      assert {:ok, {_, _, [:a]}, _} = Sourceror.parse_expression(source, from_line: 1)

      assert {:ok, {:foo, _, [[{{_, _, [:do]}, {_, _, [:ok]}}]]}, _} =
               Sourceror.parse_expression(source, from_line: 2)

      assert {:ok, {_, _, [:c]}, _} = Sourceror.parse_expression(source, from_line: 5)
    end
  end

  describe "postwalk/2" do
    test "corrects line numbers" do
      quoted =
        Sourceror.parse_string!("""
        :a
        :b
        :c
        """)

      quoted =
        Sourceror.postwalk(quoted, fn
          {:__block__, _, [:b]} = quoted, state ->
            state = Map.update!(state, :line_correction, &(&1 + 10))
            {quoted, state}

          quoted, state ->
            {quoted, state}
        end)

      assert {:__block__, _,
              [
                {:__block__, a_meta, [:a]},
                {:__block__, b_meta, [:b]},
                {:__block__, c_meta, [:c]}
              ]} = quoted

      assert a_meta[:line] == 1
      assert b_meta[:line] == 2
      assert c_meta[:line] == 13
    end
  end

  describe "to_string/2" do
    test "produces formatted output" do
      source = """
      def foo do :bar end
      """

      expected = Code.format_string!(source) |> IO.iodata_to_binary()
      actual = Sourceror.parse_string!(source) |> Sourceror.to_string()

      assert expected == actual
    end

    test "indents code" do
      source = """
      def foo do
        :bar
      end
      """

      expected =
        String.trim_trailing("""
          def foo do
            :bar
          end
        """)

      actual =
        source
        |> Sourceror.parse_string!()
        |> Sourceror.to_string(indent: 1)

      assert expected == actual

      expected =
        String.trim_trailing("""
           def foo do
             :bar
           end
        """)

      actual =
        source
        |> Sourceror.parse_string!()
        |> Sourceror.to_string(indent: 3, indent_type: :single_space)

      assert expected == actual

      expected =
        String.trim_trailing("""
        \tdef foo do
        \t  :bar
        \tend
        """)

      actual =
        source
        |> Sourceror.parse_string!()
        |> Sourceror.to_string(indent: 1, indent_type: :tabs)

      assert expected == actual
    end
  end

  describe "correct_lines/2" do
    test "corrects all line fields" do
      assert [line: 2] = Sourceror.correct_lines([line: 1], 1)
      assert [closing: [line: 2]] = Sourceror.correct_lines([closing: [line: 1]], 1)
      assert [do: [line: 2]] = Sourceror.correct_lines([do: [line: 1]], 1)
      assert [end: [line: 2]] = Sourceror.correct_lines([end: [line: 1]], 1)

      assert [end_of_expression: [line: 2]] =
               Sourceror.correct_lines([end_of_expression: [line: 1]], 1)

      assert [
               line: 2,
               closing: [line: 2],
               do: [line: 2],
               end: [line: 2],
               end_of_expression: [line: 2]
             ] =
               Sourceror.correct_lines(
                 [
                   line: 1,
                   closing: [line: 1],
                   do: [line: 1],
                   end: [line: 1],
                   end_of_expression: [line: 1]
                 ],
                 1
               )
    end
  end
end
