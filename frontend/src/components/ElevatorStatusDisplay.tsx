import React, { useState, useEffect } from 'react';
import { useElevatorWebSocket } from '../hooks/useElevatorWebSocket';

const DirectionIcon: React.FC<{ direction: string }> = ({ direction }) => {
  const style = {
    fontSize: '2em',
    color: direction === 'up' ? 'green' : direction === 'down' ? 'red' : 'gray',
    marginRight: '10px'
  };
  
  switch (direction) {
    case 'UP': return <span style={style}>⬆️ 上昇中</span>;
    case 'DOWN': return <span style={style}>⬇️ 降下中</span>;
    default: return <span style={style}>➖ 停止中</span>;
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
    <div style={{ 
      display: 'flex',
      flexDirection: 'column',
      textAlign: 'center',
       
      fontFamily: 'Arial, sans-serif', 
      padding: '20px', 
      backgroundColor: '#fff',
      borderRadius: '8px',
      boxShadow: '0 2px 5px rgba(0,0,0,0.1)',
      minWidth: '250px',
      maxWidth: '400px'
    }}>
      {/* エレベーターID */}
      <h2 style={
        {color: '#333',
         borderBottom: '2px solid #eee', 
         paddingBottom: '10px',
         textAlign: 'center',
         }}>
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
      <div style={{ 
        fontSize: '2em', 
        fontWeight: 'normal', 
        color: '#007bff', 
        border: '3px solid #007bff', 
        padding: '10px', 
        display: 'inline-block', 
        borderRadius: '8px',
        minWidth: '50px',
        backgroundColor: '#f9f9f9'
      }}>
        {currentFloor} F
      </div>
      
      <div style={{ marginTop: '20px' }}> {/* 搭乗人数と更新時間 */}
        <p style={{ fontSize: '1.2em', color: 'black' }}>
        搭乗人数: <strong style={{ color: '#333' }}>
        {occupancy} 人</strong></p>

        <p style={{ fontSize: '0.8em', color: '#888' }}>更新: {timestamp}</p>

      </div>
    </div>
  );
};

const ElevatorStatusDisplay: React.FC = () => {
  const { status, isConnected, error } = useElevatorWebSocket();
  const [showError, setShowError] = useState(false);

  useEffect(() => {
    if (error) setShowError(true);
  }, [error]);

  // statusが配列であることを期待。単一オブジェクトの場合は配列に変換、nullなら空配列
  const elevators = Array.isArray(status) ? status : (status ? [status] : []);
  const targetIds = ['E001', 'E002', 'E003'];

  return (
    <div style={{ 
      textAlign: 'center', 
      fontFamily: 'Arial, sans-serif', 
      padding: '20px', 
      backgroundColor: '#f4f4f4',
      borderRadius: '8px',
      position: 'relative', 
      minHeight: '80vh'
    }}>
    
      {showError && (
        <div style={{
          position: 'fixed',
          top: '20px',
          left: '50%',
          transform: 'translateX(-50%)',
          backgroundColor: '#ff4444',
          color: 'white',
          padding: '15px 25px',
          borderRadius: '8px',
          boxShadow: '0 4px 6px rgba(0,0,0,0.1)',
          zIndex: 1000,
          display: 'flex',
          alignItems: 'center',
          gap: '15px'
        }}>
          <span>エラー: {error}</span>
          <button 
            onClick={() => setShowError(false)}
            style={{
              background: 'none',
              border: 'none',
              color: 'white',
              fontSize: '1.2em',
              cursor: 'pointer',
              padding: '0 5px'
            }}
          >
            ✕
          </button>
        </div>
      )}

      <h1 style={{color: 'black', marginBottom: '30px'}}>エレベーター監視システム</h1>
      
      <div style={{ 
        fontSize: '1em', 
        color: isConnected ? 'green' : 'orange',
        marginBottom: '20px',
        fontWeight: 'bold'
      }}>
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