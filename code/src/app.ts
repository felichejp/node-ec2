import express, { type Express } from "express";
import routes from "./routes/index.routes";

const app: Express = express();

app.use(express.json());
app.use(routes);

export default app;
