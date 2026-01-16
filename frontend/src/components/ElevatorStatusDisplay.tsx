import React, { useState, useEffect } from 'react';
import { useElevatorWebSocket } from '../hooks/useElevatorWebSocket';

const DirectionIcon: React.FC<{ direction: string }> = ({ direction }) => {
  const style = {
    fontSize: '2em',
    color: direction === 'UP' ? 'green' : direction === 'DOWN' ? 'red' : 'gray',
    marginRight: '10px'
  };
  
  switch (direction) {
    case 'UP': return <span style={style}>⬆️ 上昇中</span>;
    case 'DOWN': return <span style={style}>⬇️ 降下中</span>;
    default: return <span style={style}>➖ 停止中</span>;
  }
};

const ElevatorStatusDisplay: React.FC = () => {
  const { status, isConnected, error } = useElevatorWebSocket();
  const [showError, setShowError] = useState(false);

  useEffect(() => {
    if (error) {
      setShowError(true);
    }
  }, [error]);

  const elevator_id = status?.elevator_id ?? '?';
  const currentFloor = status?.current_floor ?? '-';
  const occupancy = status?.occupancy ?? '-';
  const direction = status?.direction ?? 'STOP';
  const timestamp = status?.timestamp ? new Date(status.timestamp).toLocaleTimeString() : '--:--:--';

  return (
    <div style={{ 
      textAlign: 'center', 
      fontFamily: 'Arial, sans-serif', 
      padding: '20px', 
      backgroundColor: '#f4f4f4',
      borderRadius: '8px',
      position: 'relative',
      minWidth: '300px'
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

      <h1 style={{color: 'black'}}>エレベーター監視システム ({elevator_id})</h1>
      
      <div style={{ 
        fontSize: '0.8em', 
        color: isConnected ? 'green' : 'orange',
        marginBottom: '10px',
        height: '1.2em'
      }}>
        {isConnected ? '● 接続済み' : '○ 接続中...'}
      </div>

      <hr />
      
      <div style={{ margin: '30px 0' }}>
        <p style={{ fontSize: '2em', margin: '5px 0' ,color: 'black'}}>現在の状況:</p>
        <DirectionIcon direction={direction} />
      </div>

      <div style={{ 
        fontSize: '4em', 
        fontWeight: 'bold', 
        color: '#007bff', 
        border: '3px solid #007bff', 
        padding: '20px', 
        display: 'inline-block', 
        borderRadius: '10px',
        minWidth: '100px'
      }}>
        {currentFloor} F
      </div>
      
      <div style={{ marginTop: '20px' }}>
        <p style={{ fontSize: '1.5em', color: 'black' }}>搭乗人数: 
          <strong style={{ color: '#333' }}> {occupancy} 人</strong>
        </p>
        <p style={{ fontSize: '0.8em', color: '#666' }}>最終更新: {timestamp}</p>
      </div>
    </div>
  );
};

export default ElevatorStatusDisplay;