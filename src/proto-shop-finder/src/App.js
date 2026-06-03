import './App.css';
import React, { useEffect, useState } from 'react';
import styled from 'styled-components';
import {debounce} from 'lodash';
import Menu from './components/Menu/Menu';
import {KakaoMap, InitializeKakaoMap, ResizeKakaoMap} from './components/KakaoMap/KakaoMap'

const menuHeight = 100;
const startX = 33.450701;
const startY = 126.570667;

const AppDiv = styled.div`
    display: grid;
    height: ${(props) => props.width};
    grid-template-rows: ${(props) => props.height}px 1fr;
`;

function App() {

  const [windowSize, setWindowSize] = useState({
    width : window.innerWidth,
    height : window.innerHeight
  });

  const handleResize= debounce(() =>{
    setWindowSize({
      width : window.innerWidth,
      height : window.innerHeight,
    })
  }, 100);

  let isInitialized = false;

  useEffect(() => {

    InitializeKakaoMap(startX, startY);

    if(!isInitialized)
      ResizeKakaoMap(windowSize.width, windowSize.height - menuHeight);
    
    isInitialized = true;
    
    window.addEventListener('resize', handleResize);
    return () => {
      window.removeEventListener('resize', handleResize);
    }

  }, []);

  console.log('App.js is rendering');
  ResizeKakaoMap(windowSize.width, windowSize.height - menuHeight);

  return (
    <AppDiv className="App" width={windowSize.width}>
      <Menu/>
      <KakaoMap/>
    </AppDiv>
  );
}

export default App;
