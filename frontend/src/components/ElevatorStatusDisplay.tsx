import React, { useState, useEffect } from 'react';
import { useElevatorWebSocket } from '../hooks/useElevatorWebSocket.ts';
import styles from '../css/Elevator.module.css';

const DirectionIcon: React.FC<{ direction: string }> = ({ direction }) => {
  const style = {
    color: direction === 'up' ? 'green' : direction === 'down' ? 'red' : 'gray',
  };
  
  switch (direction) {
    case 'UP': return <span className={styles.direction} style={style}>⬆️ 上昇中</span>;
    case 'DOWN': return <span className={styles.direction} style={style}>⬇️ 降下中</span>;
    default: return <span className={styles.direction} style={style}>➖ 停止中</span>;
  }
};

// 個別のエレベーターカードコンポーネント
const ElevatorCard: React.FC<{ data: any }> = ({ data }) => {
  
  const elevatorid = data.elevator_id ?? '不明';
  const currentFloor = data.current_floor || '-';
  const occupancy = data.occupancy ?? '-';
  const direction = data.direction ?? 'STOP';
  const timestamp = data.timestamp ? new Date(data.timestamp).toLocaleTimeString() : '--:--:--';

  return (
    <div className={styles.elevatorIDCard}>
      {/* エレベーターID */}
      <h2 className={styles.ID}>
        ID: {elevatorid}
      </h2>
      {/* 進行方向アイコン */}
      <div style={{
         margin: '20px 0',
         textAlign: 'center'         
         }}>
        <DirectionIcon direction={direction} />
      </div>
      
      {/* 現在の階数表示 */}
      <div className={styles.currentFloorDisplay}>
        {currentFloor} F
      </div>
      
      <div style={{ marginTop: '20px' }}> {/* 搭乗人数と更新時間 */}
        <p>
        搭乗人数: <strong style={{ color: '#333' }}>
        {occupancy} 人</strong></p>

        <p style={{ fontSize: '15px', color: '#888' }}>更新: {timestamp}</p>

      </div>
    </div>
  );
};

const ElevatorStatusDisplay: React.FC = () => {
  const { status, isConnected, error } = useElevatorWebSocket();
  const [showError, setShowError] = useState("");

  useEffect(() => {
    setShowError(error || "");
  }, [error]);

  // statusが配列であることを期待。単一オブジェクトの場合は配列に変換、nullなら空配列
  const elevators = Array.isArray(status) ? status : (status ? [status] : []);
  const targetIds = ['E001', 'E002', 'E003'];

  return (
    <div className={styles.elevatorStatusDisplay}>
      <h1 style={{color: 'black', marginBottom: '30px'}}>エレベーター監視システム</h1>
      {showError && (
        <div className={styles.errorMessage}>
          <span>エラー: {showError}</span>
          <button className={styles.closeButton} onClick={() => setShowError("")}>
            ✕
          </button>
        </div>
      )}
      <div className={styles.connectionStatus} style={{color: isConnected ? 'green' : 'orange'}}>
        {isConnected ? '● 接続済み' : '○ 接続中...'}
      </div>

      <div style={{ display: 'flex', justifyContent: 'center', gap: '20px', flexWrap: 'wrap' }}>
        {targetIds.map(id => {
          const elevatorData = elevators.find((e: any) => String(e.elevator_id) === id) || { elevator_id: id };
          return <ElevatorCard key={id} data={elevatorData} />;
        })}
      </div>

    </div>
  );
};

export default ElevatorStatusDisplay;