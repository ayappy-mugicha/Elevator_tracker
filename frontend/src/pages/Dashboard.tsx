import React, {useState, useEffect} from "react";

interface ElevatorStatus {
    floor: number;
    occupancy: number;
    direction: 'UP' | 'DOWN' | 'IDLE';
}

const WS_URL = "ws://localhost:8000/ws/elevator"; // websocketのURL

const Dashboard: React.FC = () => {
    const [status, setStaus] = useState<ElevatorStatus | null> (null);
    const [isConnected, setIsConneted] = useState(false);

    useEffect(() => {
        const ws = new WebSocket(WS_URL);

        ws.onopen = () => { // 接続状態
            console.log('Websocket接続成功');
            setIsConneted(true);
        };


        ws.onmessage = (event) => {
            // JSON形式のデータを受信
            const data: ElevatorStatus = JSON.parse(event.data);
            setStaus(data);
        };
        
        // 切断したとき
        ws.close = () => {
            console.log("websocket接続切断");
            setIsConneted(false);
        };

        ws.onerror = (error) => { // 接続状態のエラー
            console.error("webSocketエラー", error);
        };
        // クリーンアップ関数
        return () => {
            ws.close();
        };
    },[]); //初回マウント時のみ実行

    // 画面表示ロジック
    return (
        <div>
            <h1>エレベータ監視</h1>
            {!isConnected && <p style={{color:'red'}}>サーバーに接続されていません</p>}

            {status ? (
                <div>
                    <p>現在の階: <strong>{status.floor}F</strong></p>
                    <p>搭乗人数: <strong>{status.occupancy}人</strong></p>
                    <p>進行方向:
                        <strong>{status.direction === 'UP' ? '↑上昇':
                        status.direction === 'DOWN' ? '↓降下':
                        '= 停止'}
                        </strong>
                    </p>
                </div>
            ): (
                <p>エレベータの初期データを待機中です</p>
            )};
        </div>
    );
};

export default Dashboard;   