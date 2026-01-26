defmodule Viban.RepoSqlite.Migrations.ConvertColumnPositionsToString do
  @moduledoc """
  Converts existing column positions from integers to strings.
  Maps: 0 -> "A", 1 -> "E", 2 -> "I", 3 -> "M", 4 -> "Q"
  Custom columns get positions after "Q".
  """

  use Ecto.Migration

  def up do
    # Convert integer positions to string positions
    # System columns: 0=A, 1=E, 2=I, 3=M, 4=Q
    execute "UPDATE columns SET position = 'A' WHERE position = '0' OR CAST(position AS INTEGER) = 0"
    execute "UPDATE columns SET position = 'E' WHERE position = '1' OR CAST(position AS INTEGER) = 1"
    execute "UPDATE columns SET position = 'I' WHERE position = '2' OR CAST(position AS INTEGER) = 2"
    execute "UPDATE columns SET position = 'M' WHERE position = '3' OR CAST(position AS INTEGER) = 3"
    execute "UPDATE columns SET position = 'Q' WHERE position = '4' OR CAST(position AS INTEGER) = 4"

    # For any custom columns with higher positions, give them positions after Q
    execute "UPDATE columns SET position = 'R' WHERE CAST(position AS INTEGER) = 5"
    execute "UPDATE columns SET position = 'S' WHERE CAST(position AS INTEGER) = 6"
    execute "UPDATE columns SET position = 'T' WHERE CAST(position AS INTEGER) = 7"
    execute "UPDATE columns SET position = 'U' WHERE CAST(position AS INTEGER) = 8"
    execute "UPDATE columns SET position = 'V' WHERE CAST(position AS INTEGER) = 9"

    # Mark system columns
    execute "UPDATE columns SET system = 1 WHERE name IN ('TODO', 'In Progress', 'To Review', 'Done', 'Cancelled')"
  end

  def down do
    # Convert back to integers
    execute "UPDATE columns SET position = 0 WHERE position = 'A'"
    execute "UPDATE columns SET position = 1 WHERE position = 'E'"
    execute "UPDATE columns SET position = 2 WHERE position = 'I'"
    execute "UPDATE columns SET position = 3 WHERE position = 'M'"
    execute "UPDATE columns SET position = 4 WHERE position = 'Q'"
    execute "UPDATE columns SET position = 5 WHERE position = 'R'"
    execute "UPDATE columns SET position = 6 WHERE position = 'S'"
    execute "UPDATE columns SET position = 7 WHERE position = 'T'"
    execute "UPDATE columns SET position = 8 WHERE position = 'U'"
    execute "UPDATE columns SET position = 9 WHERE position = 'V'"

    execute "UPDATE columns SET system = 0"
  end
end
