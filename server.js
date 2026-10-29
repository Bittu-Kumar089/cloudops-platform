const express = require("express");

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

app.get("/", (req, res) => {
  res.send("CloudOps Platform is running!");
});

app.get("/health", (req, res) => {
  res.status(200).json({
    status: "healthy",
    service: "cloudops-platform",
    timestamp: new Date().toISOString()
  });
});

if (require.main === module) {
  app.listen(PORT, "0.0.0.0", () => {
    console.log(
      `CloudOps server listening on port ${PORT}`
    );
  });
}

module.exports = app;