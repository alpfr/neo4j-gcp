from neo4j import GraphDatabase

URI = "bolt://34.86.132.248:7687"
AUTH = ("neo4j", "PassW0rdOne")


def main():
    driver = GraphDatabase.driver(URI, auth=AUTH)

    # Verify connectivity
    driver.verify_connectivity()
    print("Connected to Neo4j successfully.")

    # Create a sample node
    with driver.session() as session:
        session.run("CREATE (n:Person {name: $name, age: $age})", name="Alice", age=30)
        print("Created node: Alice")

        # Query nodes
        result = session.run("MATCH (n:Person) RETURN n.name AS name, n.age AS age")
        for record in result:
            print(f"  Name: {record['name']}, Age: {record['age']}")

        # Get node count
        result = session.run("MATCH (n) RETURN count(n) AS count")
        count = result.single()["count"]
        print(f"Total nodes in database: {count}")

    driver.close()
    print("Connection closed.")


if __name__ == "__main__":
    main()
