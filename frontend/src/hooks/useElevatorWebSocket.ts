import { useState , useEffect, useCallback, useRef } from "react";

// 受信するデータ型を定義
interface ElevatorStatus {
    elevator_id: string; // エレベーターID
    current_floor: number; // 階層
    occupancy: number; // 人数
    direction: string; // 方向 down up idel
    timestamp: string; // タイムスタンプ
}

// バックエンドのwebsocketURL Fastapi が稼働している場所を指定します。
const WS_URL = "ws://localhost:8000/ws/elevator";

export const useElevatorWebSocket = () => {
    const [status, setStatus] = useState<ElevatorStatus[]>([]);
    const [isConnected, setIsConnected] = useState(false);
    const [error, setError] = useState<string | null>(null);
    const wsRef = useRef<WebSocket | null>(null);

    // 接続処理をusecallbackでラップ
    const connect = useCallback(() =>{ // コールバックコネクト
        if (wsRef.current) {
            wsRef.current.close();
        }
        const ws = new WebSocket(WS_URL);
        wsRef.current = ws;

        ws.onopen = () => {
            console.log("Websocket接続完了");
            setIsConnected(true);
            setError(null);
        };

        ws.onmessage = (event: MessageEvent) => {
            try {
                // JSON形式のデータを受信し、型に変換
                console.log("受信データ:", event.data); // デバッグ用ログを追加
                const parsedData = JSON.parse(event.data);
                // 配列か単一オブジェクトかを判定して配列に統一
                const dataList: ElevatorStatus[] = Array.isArray(parsedData) ? parsedData : [parsedData];

                setStatus((prev) => {
                    const newStatus = [...prev];
                    dataList.forEach((data) => {
                        const index = newStatus.findIndex((e) => e.elevator_id === data.elevator_id);
                        if (index !== -1) {
                            newStatus[index] = data;
                        } else {
                            newStatus.push(data);
                        }
                    });
                    return newStatus;
                });
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
        connect();
        return () => {
            if (wsRef.current) {
                wsRef.current.onclose = null;
                wsRef.current.close();
            }
        };
    }, [connect]);
    return {status, isConnected, error};
}