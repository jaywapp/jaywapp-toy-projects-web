import styled from 'styled-components';
import parking from '../assets/parking.png'
import toilets from '../assets/toilets.png'

export const FeedTable = styled.div`
    display: grid;
    grid-template-rows: auto auto;
    text-align: center;
`

export const FeedGrid = styled.div`
    display: grid;
    grid-row: 1;
    grid-gap: 20px;
`

export const FeedBlock = styled.div`
    display: grid;
    grid-template-rows: 150px;
    
    padding-top: 15px;
    padding-bottom: 15px;
    padding-left: 15px;
    padding-right: 15px;

    text-align: center;
    border-radius: 5mm;
    background-color: #d3d3d320;
    box-shadow: 2px 2px 2px 2px lightgray;

    grid-row: ${(props) => props.row};
    grid-column: ${(props) => props.column};

    &:hover{  
        background-color : darkgray;
        color : white;
    }
`

export const Image = styled.div`
    grid-row: 1;
    background-color: black;

    height: 200px;
`

export const Description = styled.div`
    grid-row: 1;
    display: grid;
    grid-template-columns: auto 1fr;
    grid-template-rows: Auto 1fr 1fr 1fr;
`;

export const Title = styled.h3`
    grid-row: 1;
    grid-column-start: 1;
    grid-column-end: 3;
    display: flex;
`

export const AddressHeader1 = styled.div`
    grid-row: 3;
    grid-column: 1;
    display: flex;

    margin-right: 10px;
`

export const AddressHeader2 = styled.div`
    grid-row: 4;
    grid-column: 1;
    display: flex;

    margin-right: 10px;
`

export const Address1 = styled.div`
    grid-row: 3;
    grid-column: 2;
    display: flex;
`

export const Address2 = styled.div`
    grid-row: 4;
    grid-column: 2;
    display: flex;
`

export const Option = styled.div`
    grid-row: 2;
    grid-column-start: 1;
    grid-column-end: 3;
    display: flex;
`

export const Button = styled.div`
    grid-row: 2;
    margin-top: 50px;
    margin-bottom: 50px;
    text-align: center;

    border-radius: 5mm;
    background-color: #d3d3d320;
    box-shadow: 2px 2px 2px 2px lightgray;

    margin-left : 50px;
    margin-right: 50px;

    &:hover{  
        background-color : darkgray;
        color : white;
    }
`

export const MapDiv = styled.div`
    display: grid;
`;

export const MapHeader = styled.h2`
    grid-row: 1;
`

export const MapDescription = styled.div`
    grid-row: 2;
    margin-bottom: 5px;
`

export const KakaoDiv = styled.div`
    grid-row: 3;
    width: 350px;
    height: 350px;
`

export function Toilet( props ){

    if(props.hasToilet == 'Y')
        return (<img width='20px' height='20px' src={toilets}/>)

    return (<div></div>)
}

export function Parking( props ){

    if(props.hasParkingArea == 'Y')
        return (<img width='20px' height='20px' src={parking}/>)

    return (<div></div>)
}
