# Global Sets

A "global" set is a set that is scoped to records without querying by a particular ID.

For example, `OnboardingTaskTemplate` might be an admin-managed set that defines the order of tasks a user must complete during onboarding to an app.
Since the order is managed by admins, it can exist as a global order, not scoped to a particular user or organization.

Instead of using a struct for the `set_query`, you can pass an atom such as `:global`.

NOTE: This abstraction is a little suspect...
