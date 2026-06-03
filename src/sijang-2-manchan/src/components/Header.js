import styled from 'styled-components';
import longlogo from '../assets/long-logo.svg'

const TitleDiv = styled.div`
    margin-top: 30px;
    margin-bottom: 30px;
    text-align: center;
`;


function Header(){
    return (
        <TitleDiv>
            <img src={longlogo} width='350px'/>            
        </TitleDiv>
    )
}

export default Header;