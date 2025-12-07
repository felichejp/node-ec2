import express, { type Express, type Request, type Response } from "express";

const app: Express = express();
const port = process.env.PORT || 8080;

app.get('/status', (_req: Request, res: Response) => {
    res.send({ status: "Server is healthy!!!" });
});

app.listen(port, () => {
    console.log(`App is running at http://localhost:${port}!!!`);
});