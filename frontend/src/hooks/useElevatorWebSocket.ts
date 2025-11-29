import { useState , useEffect, useCallback } from "react";

// 受信するデータ型を定義
interface ElevatorStatus {
    current_floor: number; // 階層
    occupancy: number; // 人数
    direction: string; // 方向 down up idel
    timestamp: string; // タイムスタンプ
}

// バックエンドのwebsocketURL Fastapi が稼働している場所を指定します。
const WS_URL = "ws://localhost:8000/ws/elevator";

export const useElevatorWebSocket = () => {
    const [status, setStatus] = useState<ElevatorStatus | null>(null);
    const [isConnected, setIsConnected] = useState(false);
    const [error, setError] = useState<string | null>(null);

    // 接続処理をusecallbackでラップ
    const connect = useCallback(() =>{ // コールバックコネクト
        const ws = new WebSocket(WS_URL);

        ws.onopen = () => {
            console.log("Websocket接続完了");
            setIsConnected(true);
            setError(null);
        };

        ws.onmessage = (event: MessageEvent) => {
            try {
                // JSON形式のデータを受信し、型に変換
                const data: ElevatorStatus = JSON.parse(event.data);
                setStatus(data);
            } catch (e) {
                console.error("受信データ解析エラー:",e);
                setError('データの解析中に問題が発生しました');
            }
        };

        ws.onclose = () => {
            console.log("Websocket接続切断");
            setIsConnected(false);
            setTimeout(connect, 3000);
        };

        ws.onerror = (e) => {
            console.log("websocketエラー",e);
            setError("接続エラーが発生しました");
            ws.close();
        };
    }, []);

    useEffect(() => {
        const cleanup = connect();
        return cleanup;
    }, [connect]);
    return {status, isConnected, error};
}