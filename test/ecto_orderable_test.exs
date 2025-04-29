defmodule EctoOrderableTest do
  use EctoOrderable.RepoCase

  test "inserts a set and an item" do
    assert {:ok, set} = TestRepo.insert(%Set{})
    assert {:ok, _set} = TestRepo.insert(%Item{set: set})
  end
end
