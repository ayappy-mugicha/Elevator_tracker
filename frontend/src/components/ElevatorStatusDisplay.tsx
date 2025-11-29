import React from 'react';
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

  if (error) {
    return <div style={{ color: 'white', backgroundColor: 'red', padding: '10px' }}>エラー: {error}</div>;
  }

  if (!isConnected) {
    return <div style={{ color: 'gray', padding: '10px' }}>サーバーに接続中です...</div>;
  }

  if (!status) {
    return <div style={{ color: 'orange', padding: '10px' }}>エレベーターのデータを待機中です。</div>;
  }
  
  // 取得したデータを利用して表示
  return (
    <div style={{ 
      textAlign: 'center', 
      fontFamily: 'Arial, sans-serif', 
      padding: '20px', 
      backgroundColor: '#f4f4f4',
      borderRadius: '8px'
    }}>
      <h1>エレベーター監視システム (E1)</h1>
      <hr />
      
      <div style={{ margin: '30px 0' }}>
        <p style={{ fontSize: '1.2em', margin: '5px 0' }}>現在の状況:</p>
        <DirectionIcon direction={status.direction} />
      </div>

      <div style={{ 
        fontSize: '4em', 
        fontWeight: 'bold', 
        color: '#007bff', 
        border: '3px solid #007bff', 
        padding: '20px', 
        display: 'inline-block', 
        borderRadius: '10px' 
      }}>
        {status.current_floor} F
      </div>
      
      <div style={{ marginTop: '20px' }}>
        <p style={{ fontSize: '1.5em' }}>搭乗人数: 
          <strong style={{ color: '#333' }}> {status.occupancy} 人</strong>
        </p>
        <p style={{ fontSize: '0.8em', color: '#666' }}>最終更新: {new Date(status.timestamp).toLocaleTimeString()}</p>
      </div>
    </div>
  );
};

export default ElevatorStatusDisplay;