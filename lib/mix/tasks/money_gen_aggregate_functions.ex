if Code.ensure_loaded?(Ecto) do
  defmodule Mix.Tasks.Money.Gen.Postgres.AggregateFunctions do
    use Mix.Task

    import Mix.Generator
    import Mix.Ecto
    import Macro, only: [camelize: 1, underscore: 1]

    @shortdoc "Generates a migration to create aggregate types for money_with_currency"

    @moduledoc """
    Generates a migration to add a aggregation functions
    to Postgres for the `money_with_currency` type

    This release includes only the `sum` aggregattion
    function.
    """

    @doc false
    def run(args) do
      no_umbrella!("money.gen.postgres.aggregate_functions")
      repos = parse_repo(args)
      name = "add_postgres_money_aggregate_functions"

      Enum.each(repos, fn repo ->
        ensure_repo(repo, args)
        path = Path.relative_to(migrations_path(repo), Mix.Project.app_path())
        file = Path.join(path, "#{timestamp()}_#{underscore(name)}.exs")
        create_directory(path)

        assigns = [mod: Module.concat([repo, Migrations, camelize(name)])]

        create_file(file, migration_template(assigns))

        if open?(file) and Mix.shell().yes?("Do you want to run this migration?") do
          Mix.Task.run("ecto.migrate", [repo])
        end
      end)
    end

    defp timestamp do
      {{y, m, d}, {hh, mm, ss}} = :calendar.universal_time()
      "#{y}#{pad(m)}#{pad(d)}#{pad(hh)}#{pad(mm)}#{pad(ss)}"
    end

    defp pad(i) when i < 10, do: <<?0, ?0 + i>>
    defp pad(i), do: to_string(i)

    embed_template(:migration, """
    defmodule <%= inspect @mod %> do
      use Ecto.Migration

      def up do
        execute \"\"\"
          CREATE OR REPLACE FUNCTION money_state_function(agg_state money_with_currency, money money_with_currency)
          RETURNS money_with_currency
          IMMUTABLE
          LANGUAGE plpgsql
          AS $$
            DECLARE
              expected_currency char(3);
              aggregate numeric(20, 8);
              addition numeric(20,8);
            BEGIN
              if currency_code(agg_state) IS NULL then
                expected_currency := currency_code(money);
                aggregate := 0;
              else
                expected_currency := currency_code(agg_state);
                aggregate := amount(agg_state);
              end if;

              IF currency_code(money) = expected_currency THEN
                addition := aggregate + amount(money);
                return row(expected_currency, addition);
              ELSE
                RAISE EXCEPTION
                  'Incompatible currency codes. Expected all currency codes to be %', expected_currency
                  USING HINT = 'Please ensure all columns have the same currency code',
                  ERRCODE = '22033';
              END IF;
            END;
          $$;
        \"\"\"

        execute \"\"\"
          CREATE AGGREGATE sum(money_with_currency)
          (
            sfunc = money_state_function,
            stype = money_with_currency
          );
        \"\"\"
      end

      def down do
        execute "DROP AGGREGATE IF EXISTS sum(money_with_currency);"
        execute "DROP FUNCTION IF EXISTS money_state_function(agg_state money_with_currency, money money_with_currency);"
      end
    end
    """)
  end
end
