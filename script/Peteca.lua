base = 30
altura_base = 20
massa = 1
cor = {1, 1, 1}
cor_base = {0, 0, 0}
cor_pena = {0, 0, 0, 0.5}
intensidade_impulso = 100

function init()
    local world = R('world', 'world')
    body = love.physics.newBody(world, x, y, 'dynamic')
    body:setMass(massa)
    body:setAngularDamping(1)
    body:setBullet(true)
    base_shape_points = {
        -base * 0.5, 0,
        -base * 0.5, -altura_base * 0.5,
        -base * 0.25, -altura_base * 0.5,
        -base * 0.25, -altura_base,
        base * 0.25, -altura_base,
        base * 0.25, -altura_base * 0.5,
        base * 0.5, -altura_base * 0.5,
        base * 0.5, 0,
    }
    base_shape = love.physics.newPolygonShape(base_shape_points)
    pena_shape = love.physics.newPolygonShape(
        0, -altura_base,
        -base * 0.25, -altura_base * 4,
        base * 0.25, -altura_base * 4
    )
    fixture = love.physics.newFixture(body, base_shape)
    fixture:setRestitution(0.9)
    love.physics.newFixture(body, pena_shape)
end

function draw()
    love.graphics.setColor(cor_base)
    love.graphics.polygon('fill', body:getWorldPoints(unpack(base_shape_points)))
    love.graphics.setColor(cor_pena)
    love.graphics.polygon('fill', body:getWorldPoints(pena_shape:getPoints()))
    love.graphics.setColor(ultimo_a_bater and ultimo_a_bater.cor or cor)
    love.graphics.polygon('line', body:getWorldPoints(pena_shape:getPoints()))
    love.graphics.polygon('line', body:getWorldPoints(unpack(base_shape_points)))
end

function impulso(coll)
    local nx, ny = coll.nx, coll.ny
    if ny > 0 then nx, ny = -nx, -ny end
    nx = nx * intensidade_impulso
    ny = ny * intensidade_impulso
    body:applyLinearImpulse(nx, ny)
end
