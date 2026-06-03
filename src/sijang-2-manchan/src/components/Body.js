import styled from 'styled-components';
import FeedBlocks from './FeedBlocks';
import { Filter, Filtering } from "./Filter";
import { Sort, Sorting } from "./Sort";
import { useState } from "react";
import { Reference } from './Body.Style';

const BodyDiv = styled.div`
    display: grid;
    margin-left: 15%;
    margin-right: 15%;

    text-align: center;
    align-items: center;
    align-self: center;
`;

const SortDiv = styled.div`
    grid-row: 1;
    display: flex;
`;

const FilterDiv = styled.div`
    grid-row: 2;
    display: flex;
`;

const FeedBlocksDiv = styled.div`
    grid-row: 3;
`

function Body ( datas ){

    const [blocks, setBlocks] = useState(datas);

    const onSortConditionChange = (e) => {
        console.log("Body ::: Sorting Condition is changed");
        console.log(e.target.value);

        setBlocks(Sorting(e.target.value, datas));
    }

    const onFilterConditionChange = (e) => {
        console.log("Body ::: Filtering Condition is changed");
        console.log(e.target.value);

        setBlocks(Filtering(e.target.value, datas));
    }

    return(
        <BodyDiv>
            <SortDiv>
                {/* <Sort onConditionChange={onSortConditionChange}/> */}
            </SortDiv>
            <FilterDiv>
                {/* <Filter onConditionChange={onFilterConditionChange}/> */}
            </FilterDiv>
            <FeedBlocksDiv>
                <FeedBlocks/>
            </FeedBlocksDiv>
            <Reference row={4}/>
        </BodyDiv>
    )
}

export default Body;