## Many-To-Many Sets

A "many-to-many" set is the most common set, and useful in team environments, as it can be used to define many ordered sets for the same records.

For example, `TaskUser` might be used to join between `Task` and `User` records. Placing the `:order_index` field on `TaskUser` will define a set of
tasks each belonging to specific users. In doing so, we allow tasks to be ordered according to each user in an organization.
