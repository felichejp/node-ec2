import { type Request, type Response } from "express";

export const getStatus = (_req: Request, res: Response) => {
    res.send({ status: "Esta vivo!!!" });
};
