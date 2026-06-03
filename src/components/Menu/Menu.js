import React from 'react';
import { PickAround } from '../KakaoMap/KakaoMap';
import { Button, MenuDiv, LogoDiv } from '../CommonComponent';

function Menu(){
  return (
    <MenuDiv>
      <LogoDiv>토방으로뛰어</LogoDiv>
      <Button index={1} onClick={() => PickAround(1)}>반경 1KM</Button>
      <Button index={2} onClick={() => PickAround(3)}>반경 3KM</Button>
      <Button index={3} onClick={() => PickAround(5)}>반경 5KM</Button>
      <Button index={4} onClick={() => PickAround(7)}>반경 7KM</Button>
      <Button index={5} onClick={() => PickAround(10)}>반경 10KM</Button>
    </MenuDiv>
  );
}

export default Menu;