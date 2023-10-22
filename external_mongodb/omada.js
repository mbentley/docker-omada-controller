db.createUser(
  {
    user: "omada",
    pwd: "0m4d4",
    roles: [
      {
        role: "readWrite",
        db: "omada"
      },
      {
        role: "dbOwner",
        db: "omada"
      },
      {
        role: "readWrite",
        db: "omada_data"
      },
      {
        role: "dbOwner",
        db: "omada_data"
      }
    ]
  }
);
