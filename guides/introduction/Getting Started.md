# Getting Started

Ecto Orderable provides a convenient interface for ordering items in well-defined sets in your database via Ecto.

## Definitions

* A "set" can be thought of as all records in your database that can be ordered relative to each other, scoped via a query.
* An "item" is a specific record within a set, which can change its position relative to other items.
