// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library RewardAccumulator {
    uint256 public constant PRECISION = 1e18;
    // Fixed emission rates chosen for gas efficiency. To make these configurable,
    // move them to storage variables with a governance or owner-controlled setter.
    uint256 public constant GLOBAL_EMISSION_RATE = 1e17;
    uint256 public constant ENTITY_EMISSION_RATE = 1e17;

    /* ================= GLOBAL ================= */

    struct Global {
        uint256 accumulator; // G(t) = ∫ r1(t) dt
        uint256 lastRate; // r1(t)
        uint256 lastUpdate; // timestamp of last update
    }

    function updateGlobalState(Global storage g) internal {
        g.accumulator = _accumulateGlobal(g.accumulator, g.lastRate, g.lastUpdate);
        g.lastUpdate = block.timestamp;
    }

    function updateGlobalRate(Global storage g, uint256 newRate) internal {
        g.lastRate = newRate;
    }

    function previewGlobal(Global storage g) internal view returns (uint256) {
        return _accumulateGlobal(g.accumulator, g.lastRate, g.lastUpdate);
    }

    /* ================= ENTITY ================= */

    struct Entity {
        uint256 accumulator; // E(e, t) = ∫ r2(e, t) · dG
        uint256 checkpoint; // checkpointEntityGlobal(e)
        uint256 lastRate; // r2(e, t)
    }

    function updateEntityState(Entity storage e, Global storage g) internal {
        e.accumulator = _accumulateEntity(e.accumulator, e.checkpoint, e.lastRate, g.accumulator);
        e.checkpoint = g.accumulator;
    }

    function updateEntityRate(Entity storage e, uint256 newRate) internal {
        e.lastRate = newRate;
    }

    function previewEntity(Entity storage e, uint256 gAccumulator) internal view returns (uint256) {
        return _accumulateEntity(e.accumulator, e.checkpoint, e.lastRate, gAccumulator);
    }

    /* ================= ACTOR ================= */

    struct Actor {
        uint256 accumulator; // A(a, e, t) = ∫ s(a, e, t) . dE
        uint256 checkpoint; // checkpointActorEntity(a, e)
    }

    function updateActorState(Actor storage a, Entity storage e, uint256 stake, uint256 paid)
        internal
        returns (uint256 rewards)
    {
        a.accumulator = _accumulateActor(a.accumulator, a.checkpoint, stake, e.accumulator);
        a.checkpoint = e.accumulator;

        if (a.accumulator > paid) rewards = a.accumulator - paid;
    }

    function previewActor(Actor storage a, uint256 stake, uint256 eAccumulator) internal view returns (uint256) {
        return _accumulateActor(a.accumulator, a.checkpoint, stake, eAccumulator);
    }

    /* ================= INTERNAL ================= */

    function _accumulateGlobal(uint256 accumulator, uint256 rate, uint256 lastUpdate)
        private
        view
        returns (uint256 gAccumulator)
    {
        gAccumulator = accumulator;

        uint256 dt = block.timestamp - lastUpdate;
        if (dt > 0) gAccumulator += rate * dt;
    }

    function _accumulateEntity(uint256 accumulator, uint256 checkpoint, uint256 rate, uint256 gAccumulator)
        private
        pure
        returns (uint256 eAccumulator)
    {
        eAccumulator = accumulator;

        uint256 dG = gAccumulator - checkpoint;
        // Integer division truncates remainders; rewards round to zero for very small rates
        // or short intervals. Ensure sufficient stake amounts and time periods for non-zero rewards.
        if (dG > 0 && rate > 0) eAccumulator += (rate * dG) / PRECISION;
    }

    function _accumulateActor(uint256 accumulator, uint256 checkpoint, uint256 stake, uint256 eAccumulator)
        private
        pure
        returns (uint256 aAccumulator)
    {
        aAccumulator = accumulator;

        uint256 dE = eAccumulator - checkpoint;
        // Integer division truncates remainders; rewards round to zero for very small stakes
        // or short intervals. See note in _accumulateEntity.
        if (dE > 0 && stake > 0) aAccumulator += (stake * dE) / PRECISION;
    }
}
