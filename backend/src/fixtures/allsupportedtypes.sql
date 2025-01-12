CREATE TABLE
    allsupportedtypes (
        serialColumn SERIAL PRIMARY KEY,
        integerColumn INTEGER NOT NULL,
        integerArrayColumn INTEGER ARRAY NOT NULL,
        textColumn TEXT NOT NULL,
        varcharColumn VARCHAR NOT NULL,
        booleanColumn BOOLEAN NOT NULL,
        doubleColumn DOUBLE PRECISION NOT NULL,
        dateColumn DATE NOT NULL
    )