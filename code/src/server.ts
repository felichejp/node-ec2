import app from "./app";

const port = Number(process.env.PORT) || 8080;
const host = process.env.HOST || "0.0.0.0";

app.listen(port, host, () => {
    console.log(`La aplicación ya esta corriendo en http://${host}:${port}`);
});
