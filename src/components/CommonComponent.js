import styled from 'styled-components';

export const MainColor = '#2a2b34';
export const SubColor = '#3d3d4c';

export const MenuDiv = styled.div`
    display: grid;
    grid-template-columns: auto 1fr 1fr 1fr 1fr 1fr;
    grid-row: 1;
    background-color: ${MainColor};
`;


export const LogoDiv = styled.h2`
    grid-row: 1;
    color: white;
    margin-left: 10px;
    margin-right: 5px;
`;

export const Button = styled.button`
    grid-column: ${(props) => props.index + 1};
    background-color: ${SubColor};
    color: white;
    margin-top: 10px;
    margin-bottom: 10px;
    margin-left: 10px;
    margin-right: 10px;
`;

export const KakaoDiv = styled.div`
    width: 600px;
    height: 600px;
`