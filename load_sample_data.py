from neo4j import GraphDatabase

URI = "bolt://34.86.132.248:7687"
AUTH = ("neo4j", "PassW0rdOne")

PEOPLE = [
    {"name": "Bob", "age": 25, "role": "Engineer"},
    {"name": "Carol", "age": 34, "role": "Designer"},
    {"name": "Dave", "age": 28, "role": "Engineer"},
    {"name": "Eve", "age": 41, "role": "Manager"},
    {"name": "Frank", "age": 33, "role": "Analyst"},
    {"name": "Grace", "age": 29, "role": "Engineer"},
    {"name": "Hank", "age": 45, "role": "Director"},
    {"name": "Ivy", "age": 27, "role": "Designer"},
    {"name": "Jack", "age": 38, "role": "Manager"},
    {"name": "Karen", "age": 31, "role": "Analyst"},
    {"name": "Leo", "age": 26, "role": "Engineer"},
    {"name": "Mia", "age": 36, "role": "Manager"},
    {"name": "Nick", "age": 24, "role": "Intern"},
    {"name": "Olivia", "age": 32, "role": "Engineer"},
    {"name": "Paul", "age": 40, "role": "Architect"},
    {"name": "Quinn", "age": 29, "role": "Analyst"},
    {"name": "Rachel", "age": 35, "role": "Designer"},
    {"name": "Sam", "age": 42, "role": "Director"},
    {"name": "Tina", "age": 30, "role": "Engineer"},
    {"name": "Uma", "age": 27, "role": "Intern"},
]

RELATIONSHIPS = [
    ("Eve", "Bob", "MANAGES"),
    ("Eve", "Carol", "MANAGES"),
    ("Eve", "Dave", "MANAGES"),
    ("Jack", "Frank", "MANAGES"),
    ("Jack", "Grace", "MANAGES"),
    ("Jack", "Karen", "MANAGES"),
    ("Mia", "Leo", "MANAGES"),
    ("Mia", "Olivia", "MANAGES"),
    ("Mia", "Tina", "MANAGES"),
    ("Hank", "Eve", "MANAGES"),
    ("Hank", "Jack", "MANAGES"),
    ("Sam", "Mia", "MANAGES"),
    ("Sam", "Paul", "MANAGES"),
    ("Bob", "Dave", "COLLABORATES_WITH"),
    ("Grace", "Leo", "COLLABORATES_WITH"),
    ("Carol", "Ivy", "COLLABORATES_WITH"),
    ("Ivy", "Rachel", "COLLABORATES_WITH"),
    ("Frank", "Quinn", "COLLABORATES_WITH"),
    ("Nick", "Uma", "COLLABORATES_WITH"),
    ("Paul", "Hank", "REPORTS_TO"),
]


def main():
    driver = GraphDatabase.driver(URI, auth=AUTH)
    driver.verify_connectivity()
    print("Connected to Neo4j.")

    with driver.session() as session:
        # Create people
        for person in PEOPLE:
            session.run(
                "CREATE (p:Person {name: $name, age: $age, role: $role})",
                **person,
            )
            print(f"  Created: {person['name']} ({person['role']}, age {person['age']})")

        # Create relationships
        for src, dst, rel_type in RELATIONSHIPS:
            session.run(
                f"MATCH (a:Person {{name: $src}}), (b:Person {{name: $dst}}) "
                f"CREATE (a)-[:{rel_type}]->(b)",
                src=src,
                dst=dst,
            )
            print(f"  Relationship: {src} -[{rel_type}]-> {dst}")

        # Summary
        result = session.run("MATCH (n:Person) RETURN count(n) AS count")
        print(f"\nTotal Person nodes: {result.single()['count']}")

        result = session.run("MATCH ()-[r]->() RETURN count(r) AS count")
        print(f"Total relationships: {result.single()['count']}")

    driver.close()
    print("Done.")


if __name__ == "__main__":
    main()
