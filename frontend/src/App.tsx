import { StrictMode } from 'react'
import './App.css'
import ElevatorStatusDisplay from './components/ElevatorStatusDisplay'
function App() {
  return (
    <div className='App' style={{display:'flex', justifyContent:'center',alignItems:'center', minHeight:'100vh',margin:0}}>
      <ElevatorStatusDisplay />
    </div>
  )
}

export default App
